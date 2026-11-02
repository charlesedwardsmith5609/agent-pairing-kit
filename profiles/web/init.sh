#!/usr/bin/env bash
# Web profile setup. Runs inside the profile's directory.
# $1 = project name, $2 = "fullstack" when a backend lives in ../api (adds the /api dev proxy).
set -euo pipefail
name="$1"
mode="${2:-}"

cat > package.json <<EOF
{
  "name": "$name",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc --noEmit && vite build",
    "test": "vitest run --passWithNoTests",
    "typecheck": "tsc --noEmit",
    "format": "prettier --write ."
  }
}
EOF

cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noEmit": true,
    "skipLibCheck": true,
    "isolatedModules": true
  },
  "include": ["src"]
}
EOF

if [ "$mode" = "fullstack" ]; then
  proxy="
  server: {
    // Dev only: forward API calls to the backend in ../api.
    proxy: { \"/api\": \"http://localhost:8080\" },
  },"
else
  proxy=""
fi
cat > vite.config.ts <<EOF
import { defineConfig } from "vitest/config";

export default defineConfig({$proxy
  test: {
    environment: "jsdom",
  },
});
EOF

cat > index.html <<EOF
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>$name</title>
  </head>
  <body>
    <div id="app"></div>
    <script type="module" src="/src/main.ts"></script>
  </body>
</html>
EOF

mkdir -p src
printf 'export {};\n' > src/main.ts
printf 'node_modules\ndist\npackage-lock.json\n' > .prettierignore

if ! command -v npm >/dev/null 2>&1; then
  echo "web: npm not found. Install Node.js 20+ (for example via nvm) and rerun npm install." >&2
  exit 1
fi
npm install --silent --no-audit --no-fund --save-dev typescript vite vitest jsdom prettier
npx --no-install prettier --log-level warn --write .
