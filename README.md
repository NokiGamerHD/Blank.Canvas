# Blank Canvas

A 2D top-down roguelike where you draw your own character and abilities —
and the arena, a large blank canvas, gradually fills with paint as the run
goes on.

Developed by **Imperial Bay™**.

## Concept

Before each run, you draw your character and primary ability in a 36×36
pixel editor. Those drawings become the game's actual sprites. Enemies leave
permanent paint trails while chasing you, and your projectiles paint the
canvas on every hit. Over time, the battlefield becomes your own painting.

## Play

🎮 [Play in the browser (itch.io)](LINK_DO_SEU_JOGO_AQUI)

Or open the project in [Godot 4.3+](https://godotengine.org/download).

## How to play

- **WASD** or **arrow keys** — move
- Your abilities fire **automatically** at the closest enemy — focus on
  surviving (and drawing)
- Every 5 waves, choose to **upgrade an ability** or **draw a new ability**
- Survive as many waves as you can

## Main features

- A 36×36 pixel editor for the character and every ability, including a
  color palette, brush, eraser, and undo/redo
- Cumulative arena painting: enemy trails and projectile impacts
  permanently paint the canvas
- Auto-aim with configurable targeting modes (nearest, lowest health,
  farthest, random, and more)
- Endless waves with increasing difficulty and enemy variety
- Progression every 5 waves: random upgrades or a new ability
- English/Portuguese localization, switchable from the main menu
- Save the finished painted canvas as an image at the end of a run

## Technology

Built with [Godot 4.3](https://godotengine.org/) and pure GDScript. Exports
to desktop and Web.

## Project structure

```
scenes/     Godot scenes (menu, editors, arena, UI)
scripts/    source code (GDScript)
assets/     sprites, fonts, shaders, backgrounds, audio
docs/       development history and architecture decisions
```

For the complete history of technical decisions and how the project was
built, see [`docs/PROGRESS.md`](docs/PROGRESS.md).

## License

The code in this project is available under the MIT License — see
[LICENSE](LICENSE).

This does **not** necessarily cover every included asset:

- The **Press Start 2P** font (`assets/fonts/`) has its own SIL Open Font
  License — see `assets/fonts/press_start_2p_OFL.txt`.
- The **enemy sprites** (`assets/sprites/enemies/`) were supplied during
  development and their original license was not verified here. If you plan
  to keep this repository public, confirm the original sprites' terms of
  use and redistribution before publishing.

The remaining assets created during development (icon, cover art,
background textures, and sound effects) were made specifically for this
project and are covered by the MIT License above.
