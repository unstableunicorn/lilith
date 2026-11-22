#!/usr/bin/env bash
# Run everything CI runs, in CI's order. CI calls this script unchanged.
# Ends by listing what it did not cover.
#
# Usage: scripts/ci.sh                every step
#        scripts/ci.sh --only <area>  one area: dart, web, android or checks (one CI job each)
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

ONLY=""
while [ $# -gt 0 ]; do
  case $1 in
    --only)
      ONLY=${2:-}
      shift
      case $ONLY in
        dart|web|android|checks) ;;
        *) echo "--only takes dart, web, android or checks" >&2; exit 64 ;;
      esac
      ;;
    *) echo "unknown argument: $1" >&2; exit 64 ;;
  esac
  shift
done

failures=0
not_covered=()

step() { printf '\n\033[1m== %s\033[0m\n' "$1"; }
fail() { echo "FAILED: $1" >&2; failures=$((failures + 1)); }
run() { "$@" || fail "$*"; }
need() {
  command -v "$1" >/dev/null 2>&1 && return 0
  fail "$1 is not installed (needed for: $2)"
  return 1
}
area() { [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }

# coverage_total prints the line coverage of coverage/lcov.info as a percentage.
coverage_total() {
  awk -F: '/^LF:/ { lf += $2 } /^LH:/ { lh += $2 } END { if (lf) printf "%.1f%%\n", lh * 100 / lf; else print "n/a" }' coverage/lcov.info
}

if area dart; then
step "dart"
if need flutter "the app"; then
  run flutter pub get
  run dart format --output=none --set-exit-if-changed lib test
  run flutter analyze --fatal-infos
  # Coverage is reported, never enforced.
  run flutter test --coverage
  if [ -f coverage/lcov.info ]; then
    total=$(coverage_total)
    echo "  tests' line coverage: $total"
    [ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "Line coverage: $total (reported, never enforced)" >>"$GITHUB_STEP_SUMMARY"
  fi
fi
fi

if area web; then
step "web"
if need flutter "the web build"; then
  run flutter pub get
  run flutter build web --release
fi
fi

if area android; then
step "android"
if need flutter "the Android build"; then
  run flutter pub get
  run flutter build apk --debug
  # The daemon would otherwise hold memory beside whatever runs next.
  (cd android && ./gradlew --stop >/dev/null 2>&1)
fi
fi

if area checks; then
step "checks"
if need shellcheck "shell scripts"; then
  mapfile -t shells < <(git ls-files -co --exclude-standard -- 'scripts/*.sh' 'checks/*.sh' '.githooks/*' '.claude/hooks/*.sh')
  run shellcheck "${shells[@]}"
fi
if need actionlint "workflow syntax"; then
  run actionlint .github/workflows/*.yml
fi
if need zizmor "workflow security"; then
  run zizmor --persona regular .github/workflows
fi
run bash checks/secret-scan.sh --all
run bash checks/comment-density.sh
for t in checks/*.test.sh; do
  [ -f "$t" ] && run bash "$t"
done
fi

not_covered+=("the iOS build (manual, needs a Mac)")
not_covered+=("the app on a device or emulator (scripts/smoke.sh, local only)")
not_covered+=("login against a real Solid server")
not_covered+=("dependency vulnerabilities (vulns.yml runs weekly)")

echo
echo "Not covered here:"
for n in "${not_covered[@]}"; do echo "  - $n"; done
echo
if [ "$failures" -gt 0 ]; then
  echo "$failures step(s) failed" >&2
  exit 1
fi
echo "ci.sh: every step passed"
