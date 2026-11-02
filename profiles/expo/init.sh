#!/usr/bin/env bash
# Expo profile setup. Runs inside the profile's directory, which already holds the kit's files.
# $1 = project name. Creates a blank TypeScript Expo app, then adds Expo Router and the allowed
# packages. create-expo-app refuses a non-empty directory, so it runs in a temp dir first.
set -euo pipefail
name="$1"

command -v npm >/dev/null || { echo "expo: npm not found. Install Node.js 20+." >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
(cd "$tmp" && npx --yes create-expo-app@latest app --template blank-typescript --no-install)
# Move the template in without overwriting kit files (.gitignore is merged below).
cat "$tmp/app/.gitignore" >> .gitignore 2>/dev/null || true
rm -f "$tmp/app/.gitignore" "$tmp/app/App.tsx" "$tmp/app/index.ts" "$tmp/app/LICENSE"
rm -rf "$tmp/app/.git"
cp -R "$tmp/app/." .

npm install --silent --no-audit --no-fund
npx expo install expo-router react-native-safe-area-context react-native-screens expo-linking \
  expo-constants expo-status-bar zustand @react-native-async-storage/async-storage expo-audio \
  expo-keep-awake expo-speech react-native-svg react-dom
npm install --silent --no-audit --no-fund --save-dev vitest prettier

node - "$name" <<'JS'
const fs = require("fs");
const name = process.argv[2];
const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
pkg.name = name;
pkg.main = "expo-router/entry";
pkg.scripts = {
  ...pkg.scripts,
  test: "vitest run --passWithNoTests",
  typecheck: "tsc --noEmit",
  format: "prettier --write .",
  "validate-content": "node scripts/validate-content.mjs",
};
fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");

const app = JSON.parse(fs.readFileSync("app.json", "utf8"));
app.expo.name = name;
app.expo.slug = name;
app.expo.scheme = name.replace(/[^a-z0-9]/gi, "").toLowerCase();
app.expo.plugins = Array.from(new Set([...(app.expo.plugins || []), "expo-router", "expo-audio"]));
fs.writeFileSync("app.json", JSON.stringify(app, null, 2) + "\n");

const ts = JSON.parse(fs.readFileSync("tsconfig.json", "utf8"));
ts.compilerOptions = { ...(ts.compilerOptions || {}), strict: true, noUncheckedIndexedAccess: true };
ts.include = ["**/*.ts", "**/*.tsx", ".expo/types/**/*.ts", "expo-env.d.ts"];
fs.writeFileSync("tsconfig.json", JSON.stringify(ts, null, 2) + "\n");
JS

mkdir -p src/app src/engine src/components src/stores content
cat > src/app/_layout.tsx <<'TSX'
import { Stack } from "expo-router";

export default function RootLayout() {
  return <Stack screenOptions={{ headerShown: false }} />;
}
TSX
cat > src/app/index.tsx <<'TSX'
import { View } from "react-native";

export default function Home() {
  return <View />;
}
TSX
cat > vitest.config.mts <<'TS'
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    include: ["src/engine/**/*.test.ts", "tests/**/*.test.ts"],
  },
});
TS
printf 'node_modules\n.expo\ndist\nandroid\nios\npackage-lock.json\n' > .prettierignore
npx --no-install prettier --log-level warn --write .
