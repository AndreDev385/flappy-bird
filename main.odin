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

PLAYER_WIDTH :: 18 * SPRITE_SCALE
PLAYER_HEIGHT :: 18 * SPRITE_SCALE
STARTING_PLAYER_Y := f32(WINDOW_HEIGHT / 2 - PLAYER_HEIGHT / 2)

FLAP_VELOCITY :: 14

GRAVITY :: 0.65

OBSTACLE_WIDTH :: 52 * SPRITE_SCALE
OBSTACLE_HEIGHT :: 320 * SPRITE_SCALE
OBSTACLE_SPEED :: 3
GAP_SIZE :: 200

SPAWN_TIMER :: 5 // seconds

spawn_obstacle :: proc() -> Obstacle {
	initial_x: f32 = WINDOW_WIDTH + OBSTACLE_WIDTH

	min_height: f32 = 50
	max_height: f32 = FLOOR_HEIGHT - GAP_SIZE - 50

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
    first_number := world.sprites[fmt.tprint(world.score % 10)]
    second_number := world.sprites[fmt.tprint(math.floor_div(world.score, 10))]

	rl.DrawTexture(second_number, WINDOW_WIDTH / 2 - first_number.width, 40, rl.WHITE)
	rl.DrawTexture(first_number, WINDOW_WIDTH / 2, 40, rl.WHITE)
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

			for obstacle, index in world.obstacles {
				if obstacle.upper.x + obstacle.upper.width < 0 do unordered_remove(&world.obstacles, index)
			}

			// Reset when hitting the ground or obstacle
			for obstacle in world.obstacles {
				upper_collision := rl.CheckCollisionRecs(
					{world.player_x, world.player_y, f32(PLAYER_WIDTH), f32(PLAYER_WIDTH)},
					obstacle.upper,
				)
				lower_collision := rl.CheckCollisionRecs(
					{world.player_x, world.player_y, f32(PLAYER_WIDTH), f32(PLAYER_WIDTH)},
					obstacle.lower,
				)

				if upper_collision || lower_collision {
					rl.PlaySound(world.sounds["hit"])
					world.game_state = .GameOver
				}
			}
			if world.player_y + f32(PLAYER_HEIGHT) / 2 >= FLOOR_HEIGHT {
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

		{ 	// Draw base
			base := world.sprites["base"]
			w := f32(base.width) * f32(SPRITE_SCALE)
			off := math.mod_f32(world.scroll_x, w)
			rl.DrawTextureEx(base, {-off, f32(FLOOR_HEIGHT)}, 0, f32(SPRITE_SCALE), rl.WHITE)
			rl.DrawTextureEx(base, {w - off, f32(FLOOR_HEIGHT)}, 0, f32(SPRITE_SCALE), rl.WHITE)
		}


		switch world.game_state {
		case .Init:
			text: cstring = "Press SPACE to Start"
			text_size := rl.MeasureText(text, 24)

			rl.DrawText(text, WINDOW_WIDTH / 2 - text_size / 2, 40, 24, rl.WHITE)
		case .Playing:
            draw_score(&world)

            { // Draw bird
                rl.DrawRectangle(
                    i32(world.player_x),
                    i32(world.player_y),
                    PLAYER_WIDTH,
                    PLAYER_HEIGHT,
                    rl.WHITE,
                )
                rl.DrawTexturePro(
                    world.sprites["bird"],
                    {0, 0, f32(world.sprites["bird"].width), f32(world.sprites["bird"].height)},
                    {world.player_x, world.player_y, PLAYER_WIDTH, PLAYER_WIDTH},
                    {0, 0},
                    0,
                    rl.WHITE,
                )
            }
		case .GameOver:
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
