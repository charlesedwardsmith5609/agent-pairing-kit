# Expo mobile app: structure and safety

Load before writing or reviewing app code. General guidance for this kind of app, not a solution
to any specific step.

## 1. Where code goes

- `src/app/`: Expo Router routes only. A screen file reads state, picks strings from content, and
  renders shared components. Keep logic out of it.
- `src/components/`: shared UI (BigButton, ChoiceList, CheckList, TreeRunner, ResultCard...).
- `src/engine/`: pure TypeScript. No React, no React Native, no Expo imports, no `Date.now()`
  calls inside the logic: take `now` as a parameter so tests control time.
- `src/stores/`: zustand stores, persisted with AsyncStorage through zustand's `persist`
  middleware. Each store has a `version` and a `migrate` function from day one.
- `content/`: JSON. Every user-visible word. Loaded with static `import` (or `require`) so it is
  bundled; no runtime file reads.

## 2. Time and the background

- Android freezes JavaScript when the app is backgrounded or the screen locks. Never count time
  with `setInterval`. Store `startedAt`, `plannedSeconds`, `pausedSeconds` and `pausedAt`, and
  compute remaining time from the clock. An interval may only redraw the screen.
- Re-derive state on `AppState` change to `active` and on app launch (resume after a kill).
- Use `expo-keep-awake` while a timer screen is focused, and release it on blur and unmount.

## 3. Audio

- Use `expo-audio` (expo-av is deprecated). Create players with the hook or release them when
  done. Bundle clips with `require()`; a missing recording falls back to `expo-speech`
  text-to-speech of the clip's script, so the flow works before recordings exist.
- Playing audio while the screen is locked needs scheduled notifications with custom sounds and a
  development build; that is not in the demo unless a step says so.

## 4. Accessibility

- Every `Pressable` gets `accessibilityRole="button"`, an `accessibilityLabel`, and
  `accessibilityState` for selected or disabled. Minimum 48x48 dp (`minHeight: 56` for big
  buttons). Use `hitSlop` only to grow, never as the whole target.
- Test with Android's font size and display size at maximum, and with TalkBack on.
- No swipe-only actions or hidden menus. Every screen except the timer has a visible Back button.

## 5. Testing

- vitest in Node for `src/engine/`: state machines, tree walking, content assembly. Build tests
  from the spec's tables before writing the implementation.
- Pass a fake clock (`now` values) instead of sleeping.
- UI is verified on a real phone with Expo Go; record what you checked in the step report.

## 6. Agent suggestions to reject on sight

- `setInterval` or `setTimeout` as the source of truth for elapsed time.
- Literal UI text in a component, or paraphrasing approved copy from `content/`.
- A new UI kit, navigation library, state library or backend SDK without approval.
- `expo-av`, or `npm install` for an Expo package instead of `npx expo install`.
- Network calls, analytics SDKs, or API keys in the app.
- Logic in `src/engine/` that imports React Native.
