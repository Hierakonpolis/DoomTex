# DoomTex

Doom, rendered by TeX macro expansion. **One `pdflatex` run produces one frame.**

![A frame of DoomTex: an imp ahead, muzzle flash, a corpse on the floor, and the
text-mode sound block above the viewport](docs/frame.png)

That is a PDF page. The walls, the imp, the pistol, the muzzle flash, the
damage border and the status bar are all rules placed by TeX macros. The sound
is text.

```
input.txt  +  state.tex   ->   pdflatex doom.tex   ->   doom.pdf  +  state.tex
```

Run it again and you get the next frame. The PDF is the screen; `state.tex` is
the save game, written by TeX at the end of every run and read back at the start
of the next one.

There is no Lua, no `\write18`, no shell escape, and no external tool that draws
anything. The fixed-point arithmetic, the trigonometry, the DDA raycaster, the
wall textures, the monster AI and the collision detection are all TeX macros.
`play.sh` exists only to turn a keypress into a word in `input.txt`.

## Playing

```sh
./play.sh              # keyboard loop
./play.sh --new        # discard the save and start over
```

| key | action | | key | action |
|-----|--------|-|-----|--------|
| `w` / `s` | forward / back | | `f` or space | fire |
| `a` / `d` | turn left / right | | `r` | use (doors; restarts when dead) |
| `q` / `e` | strafe | | `x` | quit |

Hold shift (`W`, `A`, …) to run. `play.sh` opens `doom.pdf` in evince, which
reloads itself whenever the file changes.

### Without the script

```sh
echo "forward fire" > input.txt
pdflatex doom.tex
```

`input.txt` is plain text: whitespace-separated words on any number of lines,
from `forward back left right strafeleft straferight fire use run`. An empty
file means "stand still", which still advances a tick, so the monsters move.

## Sound

A PDF cannot make a noise, so DoomTex plays audio as text, in a fixed block
above the viewport:

```
MUS "At Doom's Gate" (E1M1)                    ██████░░  bar 17/32
------------------------------------------------------------------
> DSPISTOL    vol ██████████   L ------|------ R
> DSBGSIT1    vol ████░░░░░░   L --|---------- R
```

The volume and pan meters are computed from the distance and bearing between
the player and whatever made the sound, using the camera's right-hand vector, so
an imp waking up behind you and to the left reads as quiet and panned left. The
block is a fixed height whether three sounds are playing or none, so the frame
never shifts on the page.

## How it works

| file | what it does |
|------|--------------|
| `doom.tex` | the frame program: boot, read input, tick, render, save |
| `doomtex.sty` | screen geometry and module loading |
| `engine/fixed.tex` | fixed-point maths, safe multiply, floor division, sin/cos |
| `engine/map.tex` | the 24×24 level, as digits |
| `engine/stateio.tex` | save/load, input parsing, RNG |
| `engine/palette.tex` | 16 colours × 8 light levels |
| `engine/textures.tex` | wall textures, generated procedurally by TeX |
| `engine/sprites.tex` | hand-drawn imp, items, pistol, muzzle flash |
| `engine/raycast.tex` | the DDA raycaster and column buffer |
| `engine/render.tex` | column rasteriser and sprite overlay |
| `engine/audio.tex` | sound queue and the text-mode speaker |
| `engine/hud.tex` | weapon, damage border, status bar |
| `engine/logic.tex` | movement, collision, doors, pickups, combat, AI |

The level is a 24x24 grid of digits in `engine/map.tex`, with a start room, a
pillared hall, a stone vault behind a door, three imps, a medkit and an ammo
clip. Walls are drawn by a DDA raycaster, one ray per screen column; monsters
and items are billboard sprites depth-tested against the wall distances.

[IMPLEMENTATION.md](IMPLEMENTATION.md) covers the fixed-point arithmetic, the
box-model renderer, the procedural textures, and the `\numexpr` and PDF
rasteriser problems that shaped them.

## Performance

About 0.8 to 0.9 s per frame on TeX Live 2023 at 320x200, and roughly 1.0 s on the
first run, which also generates the sine table and the textures. Each frame is
a ~68 kB PDF.

## Requirements

`pdflatex` with `expl3`, `xcolor` and `geometry`. Nothing else. No TikZ.

```sh
pdflatex -no-shell-escape doom.tex     # works
```

## Testing

`runseq.sh` drives a scripted sequence of frames and prints the resulting world
state after each, which is how the simulation is regression-tested without a
human at the keyboard:

```sh
./runseq.sh --new "" "forward" "forward" "fire" "fire"
```
