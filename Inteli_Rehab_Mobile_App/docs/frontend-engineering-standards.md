# Inteli-Rehab — Frontend Engineering Standards (Flutter, IoT & AI-Aware)

This is the fourth and most specialized doc — it assumes you already have `coding-standards.md` (architecture/naming) and `hci-security-standards.md` (UX/security). This one is specifically about the things that go wrong in Flutter code once real-time sensor streams, 3D rendering, and AI-driven feedback enter the picture — because a "correct" architecture on paper can still rot into messy, duplicated widget code if these aren't followed deliberately.

---

## PART 1 — Frontend Code Smell Catalog (Flutter-specific)

Each smell below is something to actively watch for and fix the moment you see it, not something to clean up "later."

### Smell: God widgets
A `build()` method over ~100-150 lines, or a single file doing five visually distinct things, is a god widget. **Fix:** extract each visually distinct piece into its own named widget, even if it's only used once. A widget named `_buildExerciseHeader()` returning a `Widget` is fine as a start, but if it grows complex, promote it to an actual class — easier to test, easier to reuse.

### Smell: Business logic living inside a widget
If a `build()` method or an `onPressed` callback contains calculations, data transformations, or conditional branching based on domain rules (e.g. computing whether a rep counts, deciding a fatigue level from raw EMG), that logic is in the wrong place. **Fix:** that logic belongs in a usecase or the Bloc/Cubit — the widget's only job is to display whatever state it's handed and forward user intent (taps, form input) upward. This is the "smart vs. dumb widget" split: your `*_screen.dart` files can be smart (know about Bloc/state), but a widget like `rom_progress_ring.dart` should be dumb (pure function of its constructor parameters, zero backend/state awareness).

### Smell: Magic numbers and inline styling
`Color(0xFF149B7B)`, `EdgeInsets.all(23)`, `fontSize: 17.5` typed directly inside a screen, instead of referencing `AppTheme`/`app_colors.dart`/`app_sizes.dart`. **Fix:** if you're typing a raw hex color or a raw spacing number anywhere outside the theme/constants files, stop — add it to the theme file first, then reference it. This is exactly how two screens end up with two slightly different teals that look like a bug in your demo.

### Smell: Duplicate conditional UI logic
The same `if (quality == MovementQuality.good) return Colors.green...` mapping logic rewritten separately in three different screens (session summary, live session, progress). **Fix:** write it once as a pure function (e.g. `movementQualityColor(MovementQuality q)`) living in `shared/`, and every screen calls that function. This is the exact same "search before creating" rule from `coding-standards.md`, applied to logic instead of files.

### Smell: Deeply nested widget trees
More than 4-5 levels of nested `Container > Padding > Column > Row > ...` inside a single `build()` method becomes unreadable and hard to debug. **Fix:** extract a named sub-widget once nesting gets deep, even if it's only used in one place — readability alone justifies it.

### Smell: Missing `dispose()`
Any `AnimationController`, `StreamSubscription`, `TextEditingController`, or `VideoPlayerController` created in `initState()` that isn't cleaned up in `dispose()` is a memory leak — and in this app specifically, a BLE `StreamSubscription` left open after leaving a screen can keep draining the wearable's battery or cause duplicate data handling. **Fix:** every controller/subscription created gets a matching disposal, no exceptions — this is exactly the pattern already correctly followed in your splash/video screens; keep it everywhere.

### Smell: Unnecessary full-tree rebuilds
Calling `setState()` on an entire screen's `State` class when only one small piece of UI actually needs to update (e.g. a single number changing 30 times a second during a live session) forces Flutter to re-evaluate far more than it needs to, and is a major source of jank on lower-end devices — worth remembering given your actual test device. **Fix:** see Part 3 below — this is important enough to get its own section given how central real-time data is to this app.

### Smell: Prop drilling
Passing the same 6+ parameters down through 3+ widget layers just so the bottom-most widget can use one of them. **Fix:** either scope state properly with Bloc/Cubit (widgets read from context, not from a long constructor chain), or bundle related parameters into a single config/data object instead of a long parameter list.

---

## PART 2 — Container vs. Presentational Widget Discipline

Every screen should cleanly split into:
- **Container widgets** (`*_screen.dart`) — know about `BlocBuilder`/`BlocListener`, fetch data, handle navigation, own the loading/error/empty/success state logic
- **Presentational widgets** (everything in `shared/widgets/` and feature-local reusable pieces) — pure functions of their constructor parameters, no knowledge of Bloc, Supabase, or any backend concept whatsoever

**Test for whether a widget is properly presentational:** could you drop it into a completely unrelated Flutter app, feed it different constructor values, and have it work with zero modification? If a widget imports anything from `core/di/`, a Bloc, or a repository, it has failed this test and needs refactoring.

This split is what actually prevents duplication long-term — a properly presentational `MuscleActivationBar` gets reused everywhere it's needed (live session, session summary, replay) without three near-identical copies drifting apart from each other.

---

## PART 3 — Real-Time Sensor Data & IoT UI Rules

This is the part of the app most likely to develop invisible performance and correctness problems if built carelessly, because BLE streams arrive fast and continuously.

1. **Never bind raw high-frequency stream data directly to a full-screen `setState()`.** IMU/EMG data can arrive dozens of times per second — rebuilding an entire screen at that rate is how you get visible jank, especially on modest hardware. **Fix:** scope updates narrowly — use `ValueNotifier`/`ValueListenableBuilder` around just the specific number or graph that changes, or a `StreamBuilder` wrapping only the smallest widget that actually needs the new value.

2. **Decouple data arrival rate from render rate.** Sensor data arriving at 50-100Hz does not need to trigger 50-100 repaints per second — that's wasted work the human eye can't perceive anyway. Throttle or sample incoming values down to a sane UI refresh rate (roughly 30-60fps equivalent) before they touch a widget.

3. **Smooth, don't snap.** Raw sensor readings are noisy; a digital twin or ROM display that jumps discontinuously between readings looks broken even if the underlying data is technically correct. Interpolate/animate between values rather than hard-jumping the UI to each new raw reading.

4. **Validate and clamp before display — never show a raw sensor glitch as a real number.** If a noisy reading briefly reports an anatomically impossible value (e.g. 400° of elbow flexion), the UI should clamp it to a sane range or hold the last valid value, not display it as-is. A patient seeing "ROM: 812°" during a real session damages trust in the whole app instantly.

5. **Explicit signal-loss state, never silent extrapolation.** If BLE data stops arriving mid-session, the UI must clearly show a "Signal lost — reconnecting" state, not freeze the last frame silently or (worse) keep animating based on stale data as if it were live. The patient needs to know whether what they're seeing is real right now.

6. **Separate the ephemeral live-display state from the persisted session record.** The numbers flickering on screen during a live rep are not necessarily what gets saved to `sessions`/`session_metrics` — the saved record should be a deliberate, validated summary (e.g. computed at rep-completion), not just whatever the last raw stream value happened to be at save time.

---

## PART 4 — Digital Twin / 3D Rendering Rules

1. **Load the 3D model asset once, not on every rebuild.** Initialize the model/controller in `initState()`, never inside `build()` — reloading a `.glb` file on every rebuild is both slow and a common source of flicker.
2. **Explicit loading state for the 3D view.** The digital twin needs its own loading indicator while the model asset loads — never let the screen appear "ready" with an invisible or broken 3D viewport.
3. **Isolate the rendering technology behind an interface where practical.** If the specific 3D rendering approach (package/engine) ever needs to change, or if you want to test the surrounding UI without a real 3D context, the rest of the screen shouldn't need to know which rendering library is underneath.
4. **Profile on your actual test device early, not at the end.** A Realme C51 is a genuine test of whether your digital twin animation holds a reasonable frame rate — don't discover performance problems for the first time during your final demo. Test 3D rendering on real hardware as soon as it's functional, not just in an emulator.

---

## PART 5 — AI-Driven UI Rules

1. **Keep inference logic out of widgets entirely.** Whatever decides "this is an abnormal movement" or "fatigue threshold exceeded" is a pure function/usecase that a widget calls and displays the result of — never inline model logic inside a `build()` method or an event handler.
2. **Debounce/cooldown AI-triggered alerts.** A borderline sensor value oscillating right at a threshold shouldn't spam the patient with repeated alerts firing on and off every second. Add hysteresis — once an alert fires, require a clear margin before it can fire again, or a minimum cooldown period.
3. **Never present a model's output with more certainty than it deserves.** Frame AI feedback as guidance ("this looks like it might be compensating with your shoulder — try slowing down") rather than absolute diagnostic claims. This matters both ethically (per your SRS's disclaimer that this isn't a diagnostic tool) and for trust — overconfident wrong alerts erode a patient's willingness to trust future correct ones.
4. **AI-decision code needs to be independently testable**, without needing a live BLE connection or a real device — feed it known input arrays, assert expected classifications. This is what actually makes iterating on thresholds practical.

---

## PART 6 — Design System Discipline (extending the "no duplication" rule to visuals)

**Rule of second use:** the moment you're about to style something the same way a second time anywhere in the app, stop and extract it — a shared widget, a shared style constant, a shared spacing token. Don't wait for a third repetition to "justify" the extraction; by then it's already duplicated and already starting to drift.

**If you catch yourself copy-pasting a widget's code into a new file and changing a few values,** that's the clearest possible signal it should have been a reusable, parameterized widget instead. Stop, refactor the original into something reusable, delete the copy.

---

## PART 7 — Frontend Quality Gate (add to the review checklist in `hci-security-standards.md`)

Before considering a screen "done":
- [ ] No `build()` method over ~150 lines without extraction
- [ ] No business logic (calculations, domain decisions) inside a widget — only in Bloc/usecase
- [ ] No raw hex colors/spacing numbers outside the theme/constants files
- [ ] No duplicated conditional-styling logic across screens (single shared mapper function used everywhere)
- [ ] Every controller/subscription has a matching `dispose()`
- [ ] Any real-time data binding is scoped narrowly (ValueNotifier/StreamBuilder around the smallest necessary widget), not a full-screen `setState()`
- [ ] Sensor values are validated/clamped before display, with an explicit signal-loss state
- [ ] 3D assets load once in `initState()`, with their own loading state
- [ ] Any AI-driven alert has debounce/cooldown logic, not raw threshold-triggered spam
