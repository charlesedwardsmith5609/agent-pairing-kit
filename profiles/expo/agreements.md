### Expo mobile app (`{{DIR}}`)

- Expo (React Native) with TypeScript strict and Expo Router. Routes live in `src/app/`; pure
  logic lives in `src/engine/` and never imports `react` or `react-native`, so it can be unit tested
  with vitest in plain Node.
- Runtime dependencies already allowed: the Expo SDK packages that `create-expo-app` installs,
  `expo-router`, `zustand`, `@react-native-async-storage/async-storage`, `expo-audio`,
  `expo-keep-awake`, `expo-speech`, `react-native-svg`. Always add Expo packages with
  `npx expo install <pkg>` so versions match the SDK. Anything else needs approval.
- Dev dependencies already installed: typescript, vitest, prettier.
- Every user-visible word comes from a JSON file in `content/` (usually `content/copy.en.json`).
  No string literals inside `<Text>` in `src/app/` or `src/components/`; the check fails on them.
- No secrets or API keys in the app. Nothing in this app calls a network service unless a step
  explicitly says so.
- Accessibility is a requirement, not polish: tap targets at least 48x48 dp, body text at least
  16, every pressable has `accessibilityRole` and `accessibilityLabel`, layouts survive 200% font
  scaling (no fixed heights on text containers), never colour alone for meaning.
- Skill: read `skills/expo-mobile.md` before writing app code.
- Check stages: prettier, hard-coded UI text, tsc --noEmit, content validation
  (`node scripts/validate-content.mjs`), vitest.
