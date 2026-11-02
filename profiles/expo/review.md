- Expo / React Native: user-visible strings hard-coded in components instead of `content/`;
  timers driven by `setInterval` ticks instead of stored timestamps (breaks when the app is
  backgrounded or killed); persisted state that can't be read back after an app restart or a
  schema change; effects or listeners (AppState, audio players, keep-awake) not cleaned up on
  unmount; pressables without accessibility labels or under 48 dp; secrets in `app.json`,
  `EXPO_PUBLIC_*` variables or source; React or React Native imports inside `src/engine/`.
