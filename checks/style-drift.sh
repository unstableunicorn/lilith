#!/usr/bin/env bash
# Fail when a screen hard-codes its look. Colours, text styles, radii, sizes
# and literal spacing belong in lib/ui/theme/ or in a component under
# lib/ui/components/; screens compose those and never restyle them.
#
# Usage: checks/style-drift.sh            every screen file under lib/ui
#        checks/style-drift.sh <file>...  just those files (the test uses this)
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

if [ $# -gt 0 ]; then
  files=("$@")
else
  mapfile -t files < <(git ls-files -co --exclude-standard -- 'lib/ui/*.dart' 'lib/ui/**/*.dart' |
    grep -vE '^lib/ui/(theme|components|design)/')
fi

pattern='Color\(0x|Colors\.|TextStyle\(|BorderRadius\.|fontSize:|withValues\(|withOpacity\('
pattern="$pattern"'|EdgeInsets\.[a-zA-Z]+\([^)]*[0-9]|SizedBox\((height|width): [0-9]'
pattern="$pattern"'|(runSpacing|spacing): [0-9]'

found=0
for f in "${files[@]}"; do
  [ -f "$f" ] || continue
  while IFS= read -r hit; do
    printf '  %s:%s\n' "$f" "$hit" >&2
    found=$((found + 1))
  done < <(grep -nE "$pattern" "$f")
done

if [ "$found" -gt 0 ]; then
  echo "style-drift: $found hard-coded look(s); use the theme or a component" >&2
  exit 1
fi
echo "  style-drift: ${#files[@]} screen file(s), nothing hard-coded"
