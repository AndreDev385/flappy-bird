# Flappy Bird

A Flappy Bird clone written in [Odin](https://odin-lang.org/) with
[raylib](https://www.raylib.com/).

> This is a learning project. Its purpose was to practice physics, game states,
> file I/O, and basic game feel in Odin. It is not meant for release.

## Features

- Flap-based physics with gravity and bird rotation that follows the velocity
- Animated bird with three wing frames
- Pipes with random gap positions. The gap shrinks and the pipes speed up as
  your score grows, up to a score of 30
- Score shown with sprite digits
- Top 5 high scores saved to `high_scores.txt`
- Game over with screen shake, a white flash, sound effects, and the leaderboard
- Sound effects for flapping, scoring, hitting, and dying

## Controls

| Input | Action |
| --- | --- |
| `Space` on the title screen | Start the game |
| `Space` during play | Flap |
| `Space` on the game over screen | Restart |

## How it works

The whole game lives in `main.odin`, with three game states:

- **Init**: shows the start message and waits for `Space`.
- **Playing**: applies gravity and flaps, spawns and moves pipes, awards points
  when the bird passes a pipe, and checks for collisions with pipes or the ground.
- **GameOver**: the bird falls to the ground, the score is submitted to the
  leaderboard, and the screen flashes and shakes.

Each pipe is an `Obstacle` made of an upper and a lower rectangle that share the
same gap. Each frame, every pipe moves left and is removed once it leaves the
screen.

High scores are loaded from `high_scores.txt` at startup and written back when
a run ends with a score that makes the top 5. If the file is missing, the game
starts with an empty leaderboard.

## Running the game

You need the Odin compiler installed. The raylib bindings come with Odin
(`vendor:raylib`), so no extra install is needed.

Run the game from the project folder, because sprites, sounds, and the high
score file are loaded with relative paths:

```sh
odin run .
```

## Status

The game is playable and has the core features of Flappy Bird. Development is
paused as a practice project.

## What was learned

- Modeling a game with a `World` struct and explicit game states
- Timers for pipe spawning and wing animation, and smooth rotation toward the
  target angle
- Reading and writing text files with `core:os` and `core:strings`
- Sorting and trimming the high score list with `core:sort` and `core:strconv`
- Screen shake with a 2D camera and drawing sprites with `DrawTexturePro`

## Credits and assets

The sprites in `sprites/` and the sounds in `audio/` are MIT licensed.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
