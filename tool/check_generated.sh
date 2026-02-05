#!/usr/bin/env bash
set -euo pipefail

# Run build_runner and fail if generated files are not committed
dart run build_runner build --delete-conflicting-outputs
if [[ -n "$(git status --porcelain | grep '\.g\.dart' || true)" ]]; then
  echo "Generated files are out of date. Run: dart run build_runner build --delete-conflicting-outputs" >&2
  git --no-pager diff --name-only | grep '\.g\.dart' || true
  exit 1
fi

echo "generated files are up-to-date"