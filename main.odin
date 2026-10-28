package main

import "core:math/rand"
import rl "vendor:raylib"

GameState :: enum {
	Init,
	Playing,
}

Obstacle :: struct {
	upper: rl.Rectangle,
	lower: rl.Rectangle,
    scored: bool,
}

World :: struct {
    game_state : GameState,
    obstacles : [dynamic]Obstacle,
    score : int,
    player_size : int,
    player_y: f32,
    player_x: f32,
    player_vy: f32,
    max_obstacle_timer: f32,
    current_obstacle_timer: f32,
}

WINDOW_WIDTH :: 480 * 2
WINDOW_HEIGHT :: 320 * 2

FLOOR_HEIGHT :: WINDOW_HEIGHT - 20

STARTING_PLAYER_Y := f32(WINDOW_HEIGHT / 2 - PLAYER_SIZE / 2)
PLAYER_SIZE :: 20

FLAP_VELOCITY :: 10

GRAVITY :: 0.4

OBSTACLE_WIDTH :: 60
OBSTACLE_SPEED :: 4
GAP_SIZE :: 120

SPAWN_TIMER :: 5 // seconds

spawn_obstacle :: proc() -> Obstacle {
	initial_x: f32 = WINDOW_WIDTH + OBSTACLE_WIDTH

	min_height: f32 = 50
	max_height: f32 = WINDOW_HEIGHT - GAP_SIZE - 50

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

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Flappy bird")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

    world := World {
        game_state = GameState.Init,
        obstacles = make([dynamic]Obstacle, 0),
        player_y =STARTING_PLAYER_Y,
        player_x = f32(WINDOW_WIDTH / 2 - PLAYER_SIZE / 2),
        player_vy = 0,
        max_obstacle_timer = SPAWN_TIMER,
        current_obstacle_timer = -1
    }

	for !rl.WindowShouldClose() {

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
			}

			world.player_vy += GRAVITY
			world.player_y += world.player_vy

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

                if world.player_x > obstacle.upper.x + obstacle.upper.width / 2 && !obstacle.scored{
                    world.score += 1
                    obstacle.scored = true
                }
			}

            for obstacle, index in world.obstacles {
                if obstacle.upper.x + obstacle.upper.width < 0 do unordered_remove(&world.obstacles, index)
            }

			// Reset when hitting the ground or obstacle
            for obstacle in world.obstacles {
                upper_collision := rl.CheckCollisionRecs({world.player_x, world.player_y, f32(PLAYER_SIZE), f32(PLAYER_SIZE)}, obstacle.upper)
                lower_collision := rl.CheckCollisionRecs({world.player_x, world.player_y, f32(PLAYER_SIZE), f32(PLAYER_SIZE)}, obstacle.lower)

                if upper_collision || lower_collision do restart(&world)
            }
			if world.player_y + f32(PLAYER_SIZE) / 2 >= FLOOR_HEIGHT do restart(&world)
		}

		// ======== Draw section
		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.BLACK)

        rl.DrawRectangle(0, FLOOR_HEIGHT, WINDOW_WIDTH, 50, rl.WHITE)
        rl.DrawRectangle(
            i32(world.player_x),
            i32(world.player_y),
            i32(PLAYER_SIZE),
            i32(PLAYER_SIZE),
            rl.WHITE,
        )

        for obstacle in world.obstacles {
            rl.DrawRectangleRec(obstacle.upper, rl.WHITE)
            rl.DrawRectangleRec(obstacle.lower, rl.WHITE)
        }

		switch world.game_state {
		case .Init:
			text: cstring = "Press SPACE to Start"
			text_size := rl.MeasureText(text, 24)

			rl.DrawText(text, WINDOW_WIDTH / 2 - text_size / 2, 40, 24, rl.WHITE)
		case .Playing:
            score := rl.TextFormat("Score: {}", world.score)
            rl.DrawText(score, 40, 40, 18, rl.WHITE)
		}

	}
}
