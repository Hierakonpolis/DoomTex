# DoomTex

Doom, rendered by TeX macro expansion. **One `pdflatex` run produces one frame.**

![A frame of DoomTex: an imp ahead, muzzle flash, a corpse on the floor, and the
text-mode sound block above the viewport](docs/frame.png)

Everything above is a PDF page. The walls, the imp, the pistol, the muzzle
flash, the red damage border and the status bar are all rules placed by TeX
macros; the sound is text.

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

The volume and pan meters are not decoration. They are computed from the actual
distance and bearing between the player and whatever made the sound, using the
camera's right-hand vector, so an imp waking up behind you to the left reads as
quiet and panned left. The block is always the same height whether three sounds
are playing or none, so the frame never shifts on the page.

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

### Numbers are integers scaled by 1024

TeX has no floating point that is fast enough to use 320 times a frame, so
everything is an integer scaled by 1024. `1.0` is `1024`; angles run `0..1023`
for a full turn.

The trap that costs the most time here: **`\numexpr` rounds division, it does
not truncate.** `5/2` is `3`. Using bare `/` to turn a world coordinate into a
grid index silently reads the wrong cell, and a texture column computed as
`1023/32` comes out as `32` — one past the end of a 32-wide texture. Every
floor division goes through `\dtexFloorDiv`.

Products overflow at 2³¹, loudly (`! Arithmetic overflow`), so there are two
multiplies: `\dtexMul` for the raycaster's inner loop where both operands are
small, and `\dtexMulS`, which splits an operand, everywhere else.

### The renderer draws no coordinates

Each screen column is a `\vbox` with `\offinterlineskip` holding a stack of
coloured rules: ceiling gradient, then wall texture segments, then floor
gradient. Boxes stacked that way abut exactly, so the vertical layout falls out
of TeX's box model and there is no per-pixel positioning arithmetic at all. All
band heights are integers and each column is computed as differences from a
running cursor, so ceiling + wall + floor is always exactly 200 pixels.

This matters: at 288 dpi the output is pixel-exact, with zero blend pixels
between bands and a single colour change across 200 abutting columns. Fractional
heights produce visible seams; integers do not.

Sprites are a second pass drawn on top, positioned with `\rlap`/`\raisebox`, and
each sprite column is tested against the wall distance recorded for that screen
column, so monsters are properly hidden behind geometry.

### Lookup, don't compute

![The four wall textures, generated by TeX from pattern arithmetic and an
integer hash](docs/textures.png)

Those bitmaps are not stored as art anywhere. They are computed from pattern
arithmetic and a small integer hash; `pdflatex tools/texsheet.tex` redraws the
sheet above from the same data the renderer samples.

The sine table and the four wall textures are computed by TeX on the first run
and cached to `cache/` as flat macro calls, so later frames pay nothing. Every
texel becomes its own control sequence, making sampling a hash probe instead of
a walk along a string. Distance shading is a lookup too: 16 palette entries × 8
light levels are defined once, so shading a band costs a `\csname`, not
arithmetic.

Delete `cache/` and it regenerates itself.

## Performance

On TeX Live 2023, 320×200:

| | |
|---|---|
| cold start (both tables generated) | ~1.0 s |
| steady-state frame | ~0.77 s |
| PDF per frame | ~65 kB |

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
