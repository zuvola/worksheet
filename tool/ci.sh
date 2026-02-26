#!/usr/bin/env zsh
set -euo pipefail

# Mirrors .github/workflows/tests.yml locally.
#
# Usage:
#   tool/ci.sh          # full output
#   tool/ci.sh --brief  # last 5 lines per step (like piping through tail -5)
#
# Set FLUTTER_ROOT to override SDK location, e.g.:
#   FLUTTER_ROOT=/opt/flutter tool/ci.sh

brief=false
if [[ "${1:-}" == "--brief" ]]; then
  brief=true
fi

# Find Flutter SDK: FLUTTER_ROOT env var > 'flutter' on PATH > common locations.
if [[ -n "${FLUTTER_ROOT:-}" ]]; then
  FLUTTER="$FLUTTER_ROOT/bin/flutter"
  DART="$FLUTTER_ROOT/bin/dart"
elif command -v flutter &>/dev/null; then
  FLUTTER=flutter
  DART=dart
elif [[ -x "$HOME/flutter/bin/flutter" ]]; then
  FLUTTER="$HOME/flutter/bin/flutter"
  DART="$HOME/flutter/bin/dart"
else
  echo "Error: Flutter SDK not found. Set FLUTTER_ROOT or add flutter to PATH." >&2
  exit 1
fi

run_step() {
  local label="$1"
  shift
  echo "=== $label ==="
  if $brief; then
    "$@" 2>&1 | tr '\r' '\n' | tail -5
  else
    "$@"
  fi
  echo ""
}

run_step "Install dependencies" "$FLUTTER" pub get
run_step "Format"               "$DART" format --set-exit-if-changed lib/ test/ example/
run_step "Analyze"              "$DART" analyze lib/
run_step "Test"                 "$FLUTTER" test --coverage --exclude-tags golden
run_step "Benchmarks"           "$FLUTTER" test test/benchmarks/

echo "=== All CI checks passed ==="
