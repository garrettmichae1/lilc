#!/bin/sh
# Copy the built GitHub Pages app and the TypeScript source into the lilC repo.
# Does not modify Swift / Xcode sources.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${1:-/Users/garrettwoodside/Desktop/lilC}"

if [ ! -d "$REPO/.git" ]; then
  echo "Expected lilC git repo at $REPO" >&2
  exit 1
fi

if [ ! -f "$ROOT/dist/index.html" ]; then
  echo "Run npm run build first." >&2
  exit 1
fi

rm -rf "$REPO/web"
mkdir -p "$REPO/web"
cp -R "$ROOT/dist/." "$REPO/web/"
# Pages should not run Jekyll over wasm/underscore paths.
touch "$REPO/web/.nojekyll"

rm -rf "$REPO/apps/web"
mkdir -p "$REPO/apps"
# Source snapshot: everything except install/build artifacts.
rsync -a --delete \
  --exclude node_modules \
  --exclude dist \
  --exclude .git \
  --exclude .vite \
  "$ROOT/" "$REPO/apps/web/"

printf '%s\n' \
  '# Web app (GitHub Pages)' \
  '' \
  'This folder is the **built** lilC browser app, served at' \
  '[https://garrettmichae1.github.io/lilc/web/](https://garrettmichae1.github.io/lilc/web/).' \
  '' \
  'TypeScript source lives in `apps/web/` (same as Desktop `lilCWeb`).' \
  'Rebuild with `npm run build` in that project, then `sh scripts/publish-to-repo.sh`.' \
  'Do not mix these files with the iOS / Swift sources.' \
  > "$REPO/web/README.md"

echo "Published Pages app -> $REPO/web"
echo "Published source    -> $REPO/apps/web"
