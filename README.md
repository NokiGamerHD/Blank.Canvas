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

🎮 [Play in the browser (itch.io)](https://nokigamerhd.itch.io/blank-canvas)

Or open the project in [Godot 4.3+](https://godotengine.org/download).

## How to play

- **WASD** or **arrow keys** — move
- **Mouse** — aim
- **Left mouse button** — shoot toward the cursor (hold it to keep firing)
- Every ability has a **shot type**, picked in the ability editor: **Standard**
  curves into enemies near the end of its flight, **Charge** grows while the
  button is held and fires on release, and **Rapid** is weak but fast and
  long-ranged
- **Space** or **Shift** — dash, with a short moment of invulnerability that
  lets you pass through enemies
- **1** to **8** — use the paint flask in that slot
- **Tab** — hold to open the full arena map
- Every 2 waves, pick one of three **attack upgrades**; every 5 waves the whole
  shop opens, with character upgrades, a special perk, and the choice between
  upgrading an ability and **drawing a new one**, which keeps the shot type of
  your first ability
- Survive as many waves as you can

## Main features

- A 36×36 pixel editor for the character and every ability, including a
  color palette, brush, eraser, and undo/redo
- Cumulative arena painting: enemy trails and projectile impacts permanently
  paint the canvas
- Fresh paint shines and mixes into a new color when another trail crosses it,
  then dries after a few seconds
- Fresh paint is terrain: a single wet color slows you down, while fresh mixed
  paint is slick and speeds you up
- Mouse aiming and a dash with invulnerability frames and its own cooldown
- Three shot types per ability: homing standard, hold-to-charge and rapid fire
- Nine one-time special upgrades, three per shot type, each scaling with another
  stat (life steal, ricochet, crits, blast, shards, overcharge, venom, focus and
  momentum)
- A stats panel under the minimap with life, attack, fire rate, pierce, size,
  speed, range, dash cooldown, move speed and pickup range, plus every special
  perk taken so far
- Endless waves with increasing difficulty and enemy variety
- A boss every 10 waves, alone in its own wave: a giant square with a pulsing
  aura that takes a beating before it splits, into pieces that each take fewer
  hits, down to a single one. The pieces lob slow paint orbs at the player, every
  split sets off a huge explosion that shakes the screen and sprays wide
  paint-trailing shards to the arena walls, and one health bar tracks the whole
  family
- Enemies that bump into each other can fuse into a bigger, stronger enemy
  bubbling with foam in its own color, crackling with lightning when it fuses
  twice; two different colors fuse into the stronger enemy painted in the mixed
  color, and faster
- Enemies drop paint drops in their own ink color, collected by walking close;
  each one heals a point of life, so ink is worth chasing mid-fight
- Enemies also drop paint flasks in their color, kept in the belt under the HP
  panel: the red one adds damage and makes shots zigzag, the blue one speeds up
  shots, the player and the reload, the green one grows both the shot and the
  character, and the yellow one turns shots into seekers and refreshes the dash
- Walking over fresh paint stains the character in that color and leaves little
  puffs behind
- Bosses drop a golden palette that stays on the floor until it is picked up; it
  buys a flask slot in the character editor, up to eight, and carries over
  between runs
- Progression in two rhythms: attack upgrades in blue every 2 waves, and every 5
  waves the full shop with character upgrades in pink, a golden perk, rerolls
  paid in paint drops and new abilities bought with them
- A settings screen, from the menu and from the pause screen: sound volume,
  music volume, mute, fullscreen, screen shake, damage numbers, language,
  rebindable controls and a two-step button to erase the save data
- A hold-to-open map over the arena, which fades while the player moves
- Separate music tracks for the menu, the arena and boss waves, crossfading into
  each other, with their own volume slider
- A credits screen from the main menu
- Wave announcements on screen, with a different banner, colour and sound when a
  boss wave starts
- English/Portuguese localization, switchable from the settings screen
- Save the finished painted canvas as an image at the end of a run

## Technology

Built with [Godot 4.3](https://godotengine.org/) and pure GDScript. Exports
to desktop and Web.

## Project structure

```
scenes/     Godot scenes (menu, editors, arena, UI)
scripts/    source code (GDScript)
assets/     sprites, fonts, shaders, backgrounds, audio
press-kit/  store page and event material (screenshots, cover art, icon, banners)
```

## License

The source code in this repository is released under the MIT License — see
[LICENSE](LICENSE).

The MIT License does **not** extend to every bundled asset:

- The **Press Start 2P** font (`assets/fonts/`) is distributed under the SIL
  Open Font License — see `assets/fonts/press_start_2p_OFL.txt`.
- The **enemy sprites** (`assets/sprites/enemies/`) are third-party assets.
  No license to them is granted here, and their terms of use and
  redistribution have not been verified. Anyone reusing or redistributing
  this project is responsible for clearing those sprites independently.

- Any **music** placed in `assets/audio/music/` comes from third-party packs
  and keeps its own license, which is listed in the game's credits screen. The
  repository ships no music files; the game runs silently when the folder is
  empty.

All remaining assets — icon, cover art, background textures, and sound
effects — are original to this project and are covered by the MIT License
above.
