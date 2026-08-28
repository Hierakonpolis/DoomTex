#!/usr/bin/env bash
# ---------------------------------------------------------------------
#  DoomTex -- keyboard driver.
#
#  This script is a CONVENIENCE ONLY.  It computes nothing about the game:
#  all it does is turn a keypress into a word in input.txt and run
#  pdflatex.  Every bit of the simulation and rendering happens inside TeX.
#
#      ./play.sh            play
#      ./play.sh --new      discard the saved game and start over
# ---------------------------------------------------------------------
set -uo pipefail
cd "$(dirname "$0")"

VIEWER_PID=""
cleanup() { [[ -n "$VIEWER_PID" ]] && kill "$VIEWER_PID" 2>/dev/null; stty sane 2>/dev/null; }
trap cleanup EXIT

[[ "${1:-}" == "--new" ]] && rm -f state.tex && echo "new game"

render() {
  if ! pdflatex -interaction=nonstopmode -halt-on-error doom.tex >/dev/null 2>&1; then
    echo "!! pdflatex failed -- see doom.log"
    grep -m3 -A3 '^!' doom.log
    return 1
  fi
}

status() {
  local hp ammo kills frame
  hp=$(   sed -n 's/.*dtexS{health}{\([0-9-]*\)}.*/\1/p' state.tex)
  ammo=$( sed -n 's/.*dtexS{ammo}{\([0-9-]*\)}.*/\1/p'   state.tex)
  kills=$(sed -n 's/.*dtexS{kills}{\([0-9-]*\)}.*/\1/p'  state.tex)
  frame=$(sed -n 's/.*dtexS{frame}{\([0-9-]*\)}.*/\1/p'  state.tex)
  printf '\r\033[Kframe %-4s  health %-4s ammo %-4s kills %-3s  [wasd qe move | f fire | r use | x quit] ' \
         "$frame" "$hp" "$ammo" "$kills"
}

echo "DoomTex"
echo "  w/s forward,back   a/d turn   q/e strafe   f fire   r use   x quit"
echo "  (uppercase WASD to run)"
echo
: > input.txt
render || exit 1

if [[ -n "${DISPLAY:-}" ]] && command -v evince >/dev/null; then
  evince doom.pdf >/dev/null 2>&1 &
  VIEWER_PID=$!
  echo "opened doom.pdf in evince -- it reloads itself after each frame"
else
  echo "no display; open doom.pdf yourself, most viewers reload on change"
fi

while true; do
  status
  IFS= read -rsn1 key || break
  acts=""
  case "$key" in
    w) acts="forward" ;;      W) acts="forward run" ;;
    s) acts="back" ;;         S) acts="back run" ;;
    a) acts="left" ;;         A) acts="left run" ;;
    d) acts="right" ;;        D) acts="right run" ;;
    q) acts="strafeleft" ;;   Q) acts="strafeleft run" ;;
    e) acts="straferight" ;;  E) acts="straferight run" ;;
    f|' ') acts="fire" ;;
    r) acts="use" ;;
    x) echo; echo "bye"; break ;;
    *) acts="" ;;
  esac
  echo "$acts" > input.txt
  render || break
done
