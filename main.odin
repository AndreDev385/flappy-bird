package mai

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

GameState :: enum {
	Init,
	Playing,
	GameOver,
}

Obstacle :: struct {
	upper:  rl.Rectangle,
	lower:  rl.Rectangle,
	scored: bool,
}

Sprites :: map[string]rl.Texture2D

Sounds :: map[string]rl.Sound

World :: struct {
	game_state:             GameState,
	obstacles:              [dynamic]Obstacle,
	score:                  int,
	player_size:            int,
	player_y:               f32,
	player_x:               f32,
	player_vy:              f32,
	max_obstacle_timer:     f32,
	current_obstacle_timer: f32,
	sprites:                Sprites,
	sounds:                 Sounds,
	scroll_x:               f32,
}

SPRITE_SCALE :: 2
WINDOW_WIDTH :: 288 * SPRITE_SCALE
WINDOW_HEIGHT :: 512 * SPRITE_SCALE

FLOOR_HEIGHT :: WINDOW_HEIGHT - 112 * SPRITE_SCALE

PLAYER_WIDTH :: 34 * SPRITE_SCALE
PLAYER_HEIGHT :: 24 * SPRITE_SCALE
STARTING_PLAYER_Y := f32(WINDOW_HEIGHT / 2 - PLAYER_HEIGHT / 2)

FLAP_VELOCITY :: 4.5 * SPRITE_SCALE

GRAVITY :: 0.25 * SPRITE_SCALE

OBSTACLE_WIDTH :: 52 * SPRITE_SCALE
OBSTACLE_HEIGHT :: 320 * SPRITE_SCALE
OBSTACLE_SPEED :: 2 * SPRITE_SCALE
GAP_SIZE :: 100 * SPRITE_SCALE

SPAWN_TIMER :: 2.5 // seconds

spawn_obstacle :: proc() -> Obstacle {
	initial_x: f32 = WINDOW_WIDTH + OBSTACLE_WIDTH

	min_height: f32 = 60 * SPRITE_SCALE
	max_height: f32 = FLOOR_HEIGHT - GAP_SIZE - 60 * SPRITE_SCALE

	gap_y := rand.float32_range(min_height, max_height)

	return Obstacle {
		upper = rl.Rectangle{initial_x, 0, OBSTACLE_WIDTH, gap_y},
		lower = rl.Rectangle{initial_x, gap_y + GAP_SIZE, OBSTACLE_WIDTH, WINDOW_HEIGHT},
		scored = false,
	}
}

restart :: proc(world: ^World) {
	world.score = 0
	world.player_y = STARTING_PLAYER_Y
	world.game_state = .Init
	world.max_obstacle_timer = SPAWN_TIMER
	world.current_obstacle_timer = -1
	clear(&world.obstacles)
}

draw_score :: proc(world: ^World) {
	score := world.score

	// Highest decimal place of the score (score is never negative)
	divisor := 1
	for score / divisor >= 10 {
		divisor *= 10
	}

	// First pass: total width of the digits (they are not all the same width)
	total_width: i32
	for d := divisor; d > 0; d /= 10 {
		total_width += world.sprites[fmt.tprint((score / d) % 10)].width
	}

	// Second pass: draw the digits, centered
	x := i32(WINDOW_WIDTH / 2) - total_width / 2
	for d := divisor; d > 0; d /= 10 {
		digit := world.sprites[fmt.tprint((score / d) % 10)]
		rl.DrawTexture(digit, x, 40, rl.WHITE)
		x += digit.width
	}
}

draw_base :: proc(world: ^World, moving:= false) {
	base := world.sprites["base"]

    if !moving {
	    rl.DrawTextureEx(base, {0, f32(FLOOR_HEIGHT)}, 0, f32(SPRITE_SCALE), rl.WHITE)
        return
    }

	w := f32(base.width) * f32(SPRITE_SCALE)
	off := math.mod_f32(world.scroll_x, w)
	rl.DrawTextureEx(base, {-off, f32(FLOOR_HEIGHT)}, 0, f32(SPRITE_SCALE), rl.WHITE)
	rl.DrawTextureEx(base, {w - off, f32(FLOOR_HEIGHT)}, 0, f32(SPRITE_SCALE), rl.WHITE)
}

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Flappy bird")

	rl.InitAudioDevice()

	sounds := make(Sounds, 5)
	sounds["die"] = rl.LoadSound("audio/die.wav")
	sounds["hit"] = rl.LoadSound("audio/hit.wav")
	sounds["point"] = rl.LoadSound("audio/point.wav")
	sounds["swoosh"] = rl.LoadSound("audio/swoosh.wav")
	sounds["wing"] = rl.LoadSound("audio/wing.wav")

	sprites := make(Sprites, 20)
	sprites["0"] = rl.LoadTexture("sprites/0.png")
	sprites["1"] = rl.LoadTexture("sprites/1.png")
	sprites["2"] = rl.LoadTexture("sprites/2.png")
	sprites["3"] = rl.LoadTexture("sprites/3.png")
	sprites["4"] = rl.LoadTexture("sprites/4.png")
	sprites["5"] = rl.LoadTexture("sprites/5.png")
	sprites["6"] = rl.LoadTexture("sprites/6.png")
	sprites["7"] = rl.LoadTexture("sprites/7.png")
	sprites["8"] = rl.LoadTexture("sprites/8.png")
	sprites["9"] = rl.LoadTexture("sprites/9.png")
	sprites["background"] = rl.LoadTexture("sprites/background-day.png")
	sprites["base"] = rl.LoadTexture("sprites/base.png")
	sprites["bird"] = rl.LoadTexture("sprites/redbird-midflap.png")
	sprites["obstacle"] = rl.LoadTexture("sprites/pipe-green.png")
	sprites["gameover"] = rl.LoadTexture("sprites/gameover.png")
	sprites["start_message"] = rl.LoadTexture("sprites/message.png")

	obstacles := make([dynamic]Obstacle, 0)
	world := World {
		game_state             = GameState.Init,
		obstacles              = obstacles,
		player_y               = STARTING_PLAYER_Y,
		player_x               = f32(WINDOW_WIDTH / 2 - PLAYER_WIDTH / 2),
		player_vy              = 0,
		max_obstacle_timer     = SPAWN_TIMER,
		current_obstacle_timer = -1,
		sprites                = sprites,
		sounds                 = sounds,
		scroll_x               = 0,
	}

	rl.SetTargetFPS(60)
	for !rl.WindowShouldClose() {

		world.scroll_x += OBSTACLE_SPEED

		// UPDATE
		switch world.game_state {
		case .Init:
			if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
				world.game_state = .Playing
				world.player_vy = -FLAP_VELOCITY
			}
		case .Playing:
			if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
				world.player_vy = -FLAP_VELOCITY
				rl.PlaySound(world.sounds["wing"])
			}

			world.player_vy += GRAVITY
			if world.player_y < FLOOR_HEIGHT do world.player_y += world.player_vy
			if world.player_y < 0 {
				world.player_y = 0
				world.player_vy = 0
			}

			// Spawn obstacles timer
			world.current_obstacle_timer -= rl.GetFrameTime()
			if world.current_obstacle_timer < 0 {
				world.current_obstacle_timer = world.max_obstacle_timer
				append(&world.obstacles, spawn_obstacle())
			}

			// Move obstacles & point score
			for &obstacle in world.obstacles {
				obstacle.upper.x -= OBSTACLE_SPEED
				obstacle.lower.x -= OBSTACLE_SPEED

				if world.player_x > obstacle.upper.x + obstacle.upper.width / 2 &&
				   !obstacle.scored {
					world.score += 1
					obstacle.scored = true
					rl.PlaySound(world.sounds["point"])
				}
			}

			for i := len(world.obstacles) - 1; i >= 0; i -= 1 {
				if world.obstacles[i].upper.x + world.obstacles[i].upper.width < 0 {
					unordered_remove(&world.obstacles, i)
				}
			}

			// Reset when hitting the ground or obstacle
			for obstacle in world.obstacles {
				upper_collision := rl.CheckCollisionRecs(
					{world.player_x, world.player_y, f32(PLAYER_WIDTH), f32(PLAYER_HEIGHT)},
					obstacle.upper,
				)
				lower_collision := rl.CheckCollisionRecs(
					{world.player_x, world.player_y, f32(PLAYER_WIDTH), f32(PLAYER_HEIGHT)},
					obstacle.lower,
				)

				if upper_collision || lower_collision {
					rl.PlaySound(world.sounds["hit"])
					world.game_state = .GameOver
				}
			}
			if world.player_y + f32(PLAYER_HEIGHT) >= FLOOR_HEIGHT {
				rl.PlaySound(world.sounds["hit"])
				world.game_state = .GameOver
			}
		case .GameOver:
			world.player_vy += GRAVITY
			if world.player_y < FLOOR_HEIGHT do world.player_y += world.player_vy
			if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
				restart(&world)
			}
		}

		// ======== Draw section
		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.BLACK)

		rl.DrawTextureEx(world.sprites["background"], {0, 0}, 0, f32(SPRITE_SCALE), rl.WHITE)

		for obstacle in world.obstacles {
			texture := world.sprites["obstacle"]

			rl.DrawTextureEx(
				texture,
				{obstacle.lower.x, obstacle.lower.y},
				0,
				f32(SPRITE_SCALE),
				rl.WHITE,
			)

			rl.DrawTexturePro(
				texture,
				{0, 0, f32(texture.width), -f32(texture.height)},
				{
					obstacle.upper.x,
					obstacle.upper.y + obstacle.upper.height - f32(OBSTACLE_HEIGHT),
					f32(OBSTACLE_WIDTH),
					f32(OBSTACLE_HEIGHT),
				},
				{0, 0},
				0,
				rl.WHITE,
			)
		}

		switch world.game_state {
		case .Init:
            draw_base(&world, false)

			start_message := world.sprites["start_message"]
			rl.DrawTextureEx(
				start_message,
				{
					f32(WINDOW_WIDTH / 2 - start_message.width),
					f32(WINDOW_HEIGHT / 2 - start_message.height),
				},
				0,
				SPRITE_SCALE,
				rl.WHITE,
			)
		case .Playing:
            draw_base(&world, true)
			draw_score(&world)

			rl.DrawTexturePro(
				world.sprites["bird"],
				{0, 0, f32(world.sprites["bird"].width), f32(world.sprites["bird"].height)},
				{world.player_x, world.player_y, PLAYER_WIDTH, PLAYER_HEIGHT},
				{0, 0},
				0,
				rl.WHITE,
			)
		case .GameOver:
            draw_base(&world, false)
			draw_score(&world)
			gameover := world.sprites["gameover"]

			rl.DrawTextureEx(
				gameover,
				{f32((WINDOW_WIDTH / 2) - (gameover.width)), f32(WINDOW_HEIGHT / 3)},
				0,
				SPRITE_SCALE,
				rl.WHITE,
			)
		}
	}

	for key in sprites {
		rl.UnloadTexture(sprites[key])
	}
	for key in sounds {
		rl.UnloadSound(sounds[key])
	}
	rl.CloseAudioDevice()
	rl.CloseWindow()
}
