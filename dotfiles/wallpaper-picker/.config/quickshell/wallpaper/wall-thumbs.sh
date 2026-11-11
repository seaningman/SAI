#!/usr/bin/env bash
# Keeps ~/.cache/wallpaper-thumbs in sync with ~/Wallpapers so the picker does
# not have to decode the originals just to paint one card.
# Adapted from pocket-dots (https://github.com/diegoMalagrida/pocket-dots, GPL-3.0).
# Thumbnails are named "<original file>.jpg" so the picker can recover the original path.
set -u

SRC="${1:-$HOME/Wallpapers}"
DST="${2:-$HOME/.cache/wallpaper-thumbs}"
GEOM="900x420^"
JOBS=4

command -v magick >/dev/null 2>&1 || exit 0
[ -d "$SRC" ] || exit 0
mkdir -p "$DST" || exit 0

while IFS= read -r -d '' img; do
    out="$DST/$(basename "$img").jpg"
    if [ -s "$out" ] && [ ! "$img" -nt "$out" ]; then
        continue
    fi
    # Write to a temporary file and rename so the picker never reads a half-written thumbnail.
    ( if magick "$img" -auto-orient -thumbnail "$GEOM" -strip -quality 85 "$out.tmp" 2>/dev/null; then
        mv -f -- "$out.tmp" "$out"; else rm -f -- "$out.tmp"; fi ) &
    while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do wait -n; done
done < <(find "$SRC" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0)
wait

find "$DST" -maxdepth 1 -type f -name '*.jpg.tmp' -delete 2>/dev/null

while IFS= read -r -d '' thumb; do
    base="$(basename "$thumb")"
    [ -f "$SRC/${base%.jpg}" ] || rm -f -- "$thumb"
done < <(find "$DST" -maxdepth 1 -type f -name '*.jpg' -print0)

exit 0
