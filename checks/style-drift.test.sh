#!/usr/bin/env bash
# Tests checks/style-drift.sh on files written here.
set -uo pipefail
# shellcheck source=checks/testlib.sh
. "$(dirname "$0")/testlib.sh"
testlib_start style-drift

cat > "$work/clean.dart" <<'DART'
Padding(padding: Space.page, child: Text(x, style: Theme.of(context).textTheme.titleLarge));
const SizedBox(height: Space.lg);
Icon(Icons.spa, color: Theme.of(context).colorScheme.primary);
DART
cat > "$work/drift.dart" <<'DART'
Text(x, style: TextStyle(color: Colors.red));
const SizedBox(height: 16);
Padding(padding: const EdgeInsets.all(12));
DART

if ! bash checks/style-drift.sh "$work/clean.dart" >/dev/null 2>&1; then
  fail "a screen using the theme and tokens passes"
fi
if out=$(bash checks/style-drift.sh "$work/drift.dart" 2>&1); then
  fail "a screen with literal styles fails"
fi
case $out in
  *"drift.dart:1"*"drift.dart:2"*"drift.dart:3"*) ;;
  *) fail "every offending line is named: $out" ;;
esac

testlib_finish
