#!/usr/bin/env bash
# Drive a scripted sequence of frames and report world state after each.
# Used for regression-testing the simulation without a human at the keyboard.
cd "$(dirname "$0")"
[[ "${1:-}" == "--new" ]] && { rm -f state.tex; shift; }
get() { sed -n "s/.*dtexS{$1}{\([0-9-]*\)}.*/\1/p" state.tex; }
for acts in "$@"; do
  echo "$acts" > input.txt
  if ! pdflatex -interaction=nonstopmode -halt-on-error doom.tex >/dev/null 2>&1; then
    echo "FAILED on '$acts'"; grep -m2 -A4 '^!' doom.log; exit 1
  fi
  imps=$(sed -n 's/.*dtexE{\([0-9]*\)}{1}{[0-9-]*}{[0-9-]*}{\([0-9-]*\)}{\([0-9-]*\)}.*/i\1:hp\2,st\3/p' state.tex | tr '\n' ' ')
  printf 'f%-3s %-20s px=%-6s py=%-6s ang=%-4s hp=%-4s ammo=%-4s k=%-3s %s\n' \
    "$(get frame)" "[$acts]" "$(get px)" "$(get py)" "$(get ang)" \
    "$(get health)" "$(get ammo)" "$(get kills)" "$imps"
done
