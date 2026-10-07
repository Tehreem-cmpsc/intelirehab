# The digital twin: how it works, from the band to the pixels

The digital twin is the 3D arm that mirrors the patient. When the patient bends their elbow, the arm on screen bends the same
amount; the muscle glows with their effort; the whole arm tints green, amber or red with the safety state. This document explains
every part of it: the code, the libraries, the functions, and the order things happen in.

---

## 1. What "the twin" is in the app (three forms)

| Form | Where | What it is | Driven by |
|---|---|---|---|
| **Live 3D twin** | Active session screen | A Three.js scene in a WebView: a rigged arm that bends, glows and tints | The band's real data, live |
| **2D twin** | Same place, as a fallback | A flat drawing of two bones and a joint (`LiveDigitalTwin`) | The joint angle and safety tier |
| **Static 3D arm** | Home screen | A rotatable model viewer (`ArmModelViewer` in `DigitalTwinCard`) | Nothing live; it is a reference model |

Most of this document is about the first one, the live 3D twin. It is the only one that moves with the patient.

---

## 2. The big picture

```
ARMBAND (ESP32)
  elbow angle + muscle %  --8 bytes, ~31 per second, Bluetooth LE-->  ArmBandBleService
                                                                          |  samples stream
                                                                          v
WearableConnectionController.liveSamples  -------------------------->  LiveTwinView  (Flutter widget)
                                                                          |
LiveSession.currentTier (green/amber/red) ------------------------->  LiveTwinView.tier
                                                                          |
                                                                          v
                                                                     TwinBridge        (Dart, no WebView knowledge)
                                                                          |  small JavaScript calls, at most ~30 a second
                                                                          v
                          WebView  <--- page served from 127.0.0.1 by TwinAssetServer
                             |
                             v
                    assets/twin/twin.js  (our scene code)  +  three_bundle.js (Three.js + GLTFLoader)
                             |
                             v
                    WebGL canvas: rigged arm model Arm_L.gltf / Arm_R.gltf
                             |
        page tells Flutter "ready" / "error" via the `Twin` JavaScript channel (back to TwinBridge)
```

Data goes **down** as JavaScript calls (`twin.setElbow(...)`) and **back up** as short JSON messages (`ready`, `error`).

---

## 3. Libraries and technologies used

| What | Used for |
|---|---|
| **Three.js 0.170** | The 3D engine in the page: scene, camera, lights, renderer, loading the model, bones and skinning, materials |
| **GLTFLoader** (part of Three.js) | Reads the `.gltf` arm model and its `.bin` data |
| **WebGL** | What Three.js draws with, inside the WebView |
| **esbuild** (build time only) | Bundles Three.js and GLTFLoader into one file, `three_bundle.js`, so the page needs no module loading |
| **`webview_flutter`** | Shows the web page inside the app, runs JavaScript in it, and receives its messages through a JavaScript channel |
| **`dart:io` `HttpServer`** | A tiny web server on the phone (`TwinAssetServer`) that serves the page and model files |
| **`dart:convert`, `dart:async`** | Decoding the page's JSON messages; timers for throttling |
| **Flutter `CustomPainter`** | The 2D fallback drawing |
| **`model_viewer_plus`** | The separate Home screen model viewer (Google's `<model-viewer>`) |
| **Android network security config** | Allows plain HTTP to `127.0.0.1` only, which is what the local server needs |

---

## 4. The files

| File | What it does |
|---|---|
| `lib/features/twin/live_twin_view.dart` | The widget on screen. Owns the WebView, listens to the band, decides when to show 3D or the 2D fallback |
| `lib/features/twin/twin_controller.dart` | `TwinController` (the interface) and `TwinBridge` (the Dart-to-JavaScript messenger) |
| `lib/features/twin/twin_asset_server.dart` | The loopback web server that feeds the WebView |
| `assets/twin/index.html` | The page: error hooks, a WebGL check, loads the two scripts |
| `assets/twin/twin.js` | The scene: model loading, skinning, flexion calibration, muscle shader, camera, animation loop, the `window.twin` API |
| `assets/twin/three_bundle.js` | Generated: Three.js + GLTFLoader, exposed as `window.ThreeBundle` |
| `tool/twin_bundle/entry.js`, `package.json` | How `three_bundle.js` is built (`npm run build`); not shipped in the app |
| `assets/models/Arm_L.gltf/.bin`, `Arm_R.gltf/.bin` | The left and right arm models |
| `lib/features/exercises/widgets/live_digital_twin.dart` | The 2D fallback |
| `lib/features/home/widgets/digital_twin_card.dart`, `arm_model_viewer.dart` | The Home screen's static 3D arm and its metrics |
| `android/app/src/main/res/xml/network_security_config.xml` | Permits cleartext HTTP to `127.0.0.1` only |
| `test/twin_test.dart`, `test/live_twin_view_test.dart` | Tests (section 13) |

The design keeps the rest of the app away from the WebView: screens and `LiveSession` only know the `TwinController` interface
(`setElbow`, `setTier`, `setEmg`, `setSide`). The renderer behind it could be replaced by a native 3D engine without touching them.

---

## 5. Start-up, step by step

When the active session screen builds a `LiveTwinView` (180 by 180 on screen):

1. **`initState`** creates a `TwinBridge`, wires its `onReady` and `onError` callbacks, hands it the patient's arm side (left or
   right) and the current safety tier, starts listening to the band's sample stream, and calls `_start()`.
2. **`_start()`** builds a `WebViewController`: JavaScript on, transparent background, and a JavaScript channel named `Twin` whose
   messages go to `TwinBridge.handleMessage`. A navigation delegate records page events and fails the twin if the main page can't load.
   If the platform has no WebView (desktop, tests) this throws, and the widget goes straight to the 2D fallback.
3. A **12-second timer** starts. If the model isn't ready by then, the twin is declared failed.
4. **`TwinAssetServer.pageUri(query: {side})`** starts the loopback server on first use (a random free port on `127.0.0.1`, one
   server for the whole app) and returns `http://127.0.0.1:<port>/twin/index.html?side=left`.
5. The WebView **loads that page**. `index.html` first installs error hooks (any script error or unhandled promise is reported to
   Flutter) and checks that WebGL exists (reporting an error if not). Then it loads `three_bundle.js` and `twin.js`.
6. **`twin.js` runs `init()`**: creates the WebGL renderer (transparent, pixel ratio capped at 2), the scene, a camera (field of view
   30), a soft hemisphere light and a directional light attached to the camera (so the arm is always lit from the viewer's side),
   registers the resize and visibility handlers, then calls `loadModel()` and starts the animation loop.
7. **`loadModel()`** fetches `../models/Arm_L.gltf` (or `Arm_R`) from the same server, then prepares it (section 7). When everything
   is set up it posts `{"type":"ready"}` to Flutter.
8. **`TwinBridge.handleMessage('ready')`** marks the page ready, forgets what it last sent, immediately sends the current tier and
   the latest elbow and muscle values, and calls `onReady`.
9. **`LiveTwinView._onReady`** cancels the timeout and shows the WebView. Until this moment the 2D drawing was laid over the top, so
   the patient never sees an empty box.

---

## 6. Every sample, step by step

```
band sample (elbowDeg, emg1Pct)
   |
   v  LiveTwinView._listen():  _bridge.setElbow(elbowDeg);  _bridge.setEmg(biceps: emg1Pct)
   |
   v  TwinBridge keeps only the newest values in _elbow / _biceps
   |
   v  _scheduleFlush():  has it been 33 ms since the last send?
   |        yes -> _flush() now          no -> a single trailing Timer runs _flush() when 33 ms are up
   v
   _flush():  build only the calls that actually changed:
              twin.setElbow(x)   if the angle moved by 0.1 degree or more
              twin.setEmg(b,t)   if either muscle value moved by 0.5 or more
              -> one JavaScript string, run in the WebView
   |
   v  window.twin.setElbow(deg):  clamp to -30..200, store as the TARGET
      window.twin.setEmg(b,t):    clamp to 0..100, store as the TARGET
   |
   v  the animation loop (about 60 times a second, independent of the samples):
         step():       move the current values toward the targets  (smooth easing)
         applyPose():  turn the forearm bone to the elbow angle
         applyEmg():   update the muscle colour and bulge
         render()
```

Why it is built this way:
- Samples arrive at about 31 a second, but the screen only needs the latest one, so the bridge **drops** old values instead of
  queueing them. A slow WebView can fall behind by at most one update.
- Skipping calls that wouldn't change anything saves work on the phone.
- The page only moves a **target**; the animation loop eases toward it, closing about 35% of the gap per 60 Hz frame
  (`1 - (1 - 0.35)^(dt*60)`, so it looks the same at 30 or 60 frames a second). That is what makes 31 Hz data look smooth.
- NaN and infinite values from the band are ignored (`isFinite` checks).

**The safety tier** goes a different way: `LiveSession` decides it, the active session screen passes it as `tier`, and
`didUpdateWidget` calls `_bridge.setTier`. Tier changes are sent immediately (not throttled) but only when the tier actually changes.

---

## 7. Inside `twin.js`: what each part does

### 7.1 The model and why it needs fixing at load time
`Arm_L.gltf` contains these named parts: bones `hand`, `forearm`, `upper_arm` (inside an `Armature`), one arm mesh (`Arm_L`, material
`lambert2SG`), and two placeholder meshes `bicep_R` and `tricep_R` (materials `Biceps_MAT`, `Triceps_MAT`). The file has a skeleton but
**the arm mesh is not attached to it** (no skin weights), so moving the forearm bone would move nothing. The script fixes this at runtime.

### 7.2 `loadModel()`
Loads the file for the chosen side, ignoring the result if the side changed during loading (`loadToken`). Then, in order:
finds the `forearm` and `upper_arm` bones (error if the forearm is missing) and remembers the forearm's rest orientation; moves the
placeholder muscle meshes under the upper arm; calls `skinArmMesh()`; turns off frustum culling (the skinned bounds go stale when bones
move); finds the materials; calls `autoCalibrateFlexion()` (unless an `axis` was given in the URL), `computeFlexFront()`,
`installMuscleHighlight()`, `computeFraming()`, `frameCamera()` and `applyTier()`; then posts `ready`.

### 7.3 `skinArmMesh()`: making the elbow bend
For every vertex of the arm mesh it works out how far along the forearm direction the vertex is, relative to the elbow, and gives it
two bone weights: vertices below the elbow follow the **forearm**, vertices above follow the **upper arm**, with a short smooth
blend across the joint (a smoothstep over 18% of the forearm length on each side). That blend is why the elbow bends like a real
elbow instead of hinging like a door. It then builds a Three.js `SkinnedMesh` with a two-bone `Skeleton` and swaps it in for the
rigid mesh.

### 7.4 `autoCalibrateFlexion()`: finding which way the elbow bends
The model's bone axes are arbitrary, so the script does not hard-code which axis is the hinge. It tries each of the three axes in
both directions at 90 degrees, and keeps the one that moves the hand furthest toward the **front** of the arm (the palm side).
Supporting functions:
- `handFront()` finds the front by looking at the fingertips: relaxed fingers curl toward the palm, so the average offset of the
  fingertip vertices from the forearm line points to the front.
- `upperArmUp()` gives the direction from the elbow up the upper arm (the bones all sit at the elbow, so it comes from the hand position).
- The result is stored in `cfg.axis` and `cfg.sign`, and the camera is turned to look straight down the hinge so the bend is seen in profile.

### 7.5 `applyPose()`: the bend itself
Every frame it builds a rotation of `sign * (elbowNow + offsetDeg)` degrees around the chosen axis and applies it to the forearm bone,
starting from its stored rest orientation. Because the mesh is skinned, the visible arm bends.

### 7.6 The muscle highlight: `computeFlexFront()`, `installMuscleHighlight()`, `applyEmg()`
The placeholder muscle meshes sit inside the arm and can't be seen, so activation is **painted onto the arm itself**:
1. `computeFlexFront()` finds the world direction the hand swings toward when the elbow flexes. Anatomically the biceps is on that side.
2. `installMuscleHighlight()` gives every arm vertex two numbers: how much it belongs to the **biceps** (front) and the **triceps**
   (back). Each is the product of a "muscle belly" band (between about 8-22% and 70-90% of the way from elbow to shoulder) and how much
   the vertex faces front or back.
3. It patches the arm material's shaders (`onBeforeCompile`): the **vertex shader** pushes those vertices outward along their normal
   by a small amount (`bulge` 0.014 model units) in proportion to effort, so the muscle visibly swells; the **fragment shader** mixes
   the skin colour toward the effort colour and adds a glow so the colour reads whatever the lighting does.
4. `applyEmg()` each frame sets the effort uniforms and picks the colour with `muscleColor()`, which blends along the ramp:

   | Effort (%MVC) | Colour |
   | --- | --- |
   | 0 | Blue |
   | 20 | Green |
   | 45 | Orange |
   | 80 | Red |

   This matches the app's muscle activation bar, so the arm and the bar agree.
5. The band has one EMG channel (biceps), so the app sends `triceps = 0` and the triceps highlight stays off (`tricepSeen` stays false).

### 7.7 The safety tier tint: `applyTier()`
Sets the arm skin's emissive (glow) colour: green `#4C9F70` for normal, amber `#E7A24C` for needs correction, red `#D96248` for unsafe.
The glow is faint when normal (0.12) and stronger otherwise (0.35).

### 7.8 Camera and framing: `computeFraming()`, `frameCamera()`, `resize()`
Measures the arm's bounding box once, then places the camera on a circle around its centre at a distance that fits the whole arm
(farther on a portrait view, where width is the limit). `resize()` keeps the renderer, camera aspect and framing in step with the view.

### 7.9 The loop: `step()`, `frame()`, `startLoop()`, `stopLoop()`
`frame()` runs through `requestAnimationFrame`: `step(dt)` then `applyPose()`, `applyEmg()`, `renderer.render()`. The time step is
capped at 0.1 s so a stall never makes the arm jump. The loop stops when the page is hidden and starts again when it returns.

### 7.10 The API Flutter calls: `window.twin`
`setElbow(deg)`, `setEmg(biceps, triceps)`, `setTier(name)`, `setSide(side)` (reloads the other arm's model), `configure({...})`
(axis, sign, offset, azimuth, colours, easing), `pause()`, `resume()`, `isReady()` and `_debug()`.

### 7.11 The developer panel
Opening the page with `?dev=1` in a normal browser shows sliders for elbow angle, hinge axis and sign, camera angle, side, tier and
muscle effort. It was used to find the hinge settings before they were automated, and is useful for checking a new model.

---

## 8. The Dart side, function by function

### `LiveTwinView` (the widget)
| Part | What it does |
|---|---|
| `initState` | Creates the bridge, starts listening and starts loading |
| `_start()` | Sets up the WebView and its channel, starts the 12-second timer, gets the page URL and loads it |
| `_listen()` | Subscribes to the band's samples and forwards them to the bridge (the band's single EMG channel drives the biceps) |
| `_onReady()` | Hides the 2D overlay once the model is ready |
| `_fail(why)` | Switches to the 2D fallback for good, and records the reason |
| `didUpdateWidget` | Pushes a changed tier, side or sample stream to the bridge; for simulated sessions (no stream) it derives degrees from the percentage |
| `didChangeAppLifecycleState` | Calls `twin.pause()` when the app goes to the background and `twin.resume()` when it returns, so nothing renders while hidden |
| `_showStatus()` | A long-press shows what the page has done so far (page started, loading, model ready, any error), so "I don't see the 3D arm" can be answered without a debugger |
| `build` | Wraps everything in a gesture detector and screen-reader label; the WebView is display-only (`IgnorePointer`), so it never fights a scroll view |

### `TwinBridge`
| Part | What it does |
|---|---|
| `setElbow`, `setEmg` | Store the newest values and schedule a flush |
| `setTier` | Sends the tier right away when it changed and the page is ready |
| `setSide` | Marks the page not ready and asks it to reload the other arm; the next `ready` re-sends everything |
| `handleMessage(raw)` | Reads the page's JSON: `ready` (push the full state, call `onReady`) or `error` (mark failed, call `onError`); anything else is ignored |
| `_scheduleFlush`, `_flush` | The 33 ms throttle and the "only what changed" filter (section 6) |
| `reset`, `dispose` | Cancel timers when the page is recreated or the widget goes away |
| `_exec` | Runs the JavaScript and swallows any failure, so a torn-down page can never crash the session screen |

### `TwinAssetServer`
A singleton. `pageUri` starts the server once (a random port on `127.0.0.1`) and builds the page address. It serves only two folders
with a fixed allow-list: `/twin/` (`index.html`, `three_bundle.js`, `twin.js`) and `/models/` (the four arm files). `assetKeyFor`
normalises the path first, so `../` tricks can only ever reach an allowed file, and everything else gets a 404. Only GET is accepted.
Files are read from the app's bundle and sent with `Cache-Control: no-cache`.

---

## 9. Left and right arms

The patient's injured side (`patients.injury_side`) picks `Arm_L.gltf` or `Arm_R.gltf`. `LiveTwinView` passes it as `side`; the page
URL carries `?side=...`. If it changes while running, `twin.setSide` removes the current model and loads the other, ignoring a
half-finished earlier load.

---

## 10. When things go wrong: the 2D fallback

The 3D view must never block a session. The widget switches to the flat 2D arm in all of these cases:

| Cause | Detected by |
|---|---|
| No WebView on this platform | Creating the controller throws |
| WebGL not available | `index.html` check posts an error |
| The page can't load | The navigation delegate's error callback |
| Script error or unhandled promise | `index.html`'s error hooks |
| `forearm` bone missing, or the model fails to load | `twin.js` posts an error |
| Nothing ready after 12 seconds | The timeout |

The 2D `LiveDigitalTwin` draws, on a 100 by 100 canvas, a fixed upper-arm bone and a forearm that swings with the angle, a joint
circle and a hand dot, in the tier colour (green, amber, red). It is fed the angle as a percentage (`fallbackPercent`), so it shows
roughly 0 to 100 degrees.

---

## 11. The Home screen's static 3D arm

`DigitalTwinCard` shows a title ("Your arm"), a source label (last session, calibration or none), an `ArmModelViewer` and a row of
metrics (joint angle and range from the last session, or from the baseline). `ArmModelViewer` uses `model_viewer_plus` (Google's
`<model-viewer>`, bundled in the app so it works offline) to show a model the patient can rotate and zoom, with a slow idle spin.
Without a side it shows the generic `arm_anatomy.glb`. It is **static**: history and baseline, not a live feed.

---

## 12. Security and limits of the local server

- It listens on **loopback only**, so nothing outside the phone can reach it, and nothing leaves the device.
- The allow-list is exactly seven files; every other path is a 404.
- Android blocks plain HTTP by default; the network security config allows it for `127.0.0.1` alone.
- The WebView ignores touches, so the page can't be interacted with or scripted by the patient.

---

## 13. Tests

| Test | What it checks |
|---|---|
| `TwinAssetServer.assetKeyFor` | The page, scripts and models map correctly; `../` is normalised to an allowed file; everything else is refused |
| `TwinAssetServer over HTTP` | The real server serves the page and model from the bundle and 404s the rest |
| `TwinBridge` | Nothing is sent before ready; on ready the latest tier and values are pushed; a burst becomes one call plus one trailing call with the newest value; unchanged values are skipped; NaN and infinity are ignored; tier changes go out immediately and only when changed; a side change reloads and re-pushes; errors flag failure; garbage messages are ignored; a throwing JavaScript call never reaches the caller |
| `LiveTwinView` | With no WebView available, it falls back to the 2D twin |

The scene code itself (`twin.js`) runs in a real browser engine, so it is checked by running the app (and the `?dev=1` panel), not by these tests.

---

## 14. Changing or extending it

- **Change the scene code**: edit `assets/twin/twin.js`; it is plain JavaScript, no build step.
- **Change Three.js or its parts**: edit `tool/twin_bundle/entry.js`, then `cd tool/twin_bundle; npm install; npm run build`. The generated
  `three_bundle.js` is committed, so building the app never needs Node.
- **New model**: drop the files in `assets/models/`, add them to the server's allow-list and to `pubspec.yaml`, and make sure the bones
  are named `hand`, `forearm`, `upper_arm`. Use `?dev=1` to check the bend.
- **Different colours**: `cfg.tierColors` and `cfg.muscleStops` at the top of `twin.js`.
- **Second muscle channel**: pass a real triceps value to `setEmg` and the triceps highlight turns on by itself.

---

## 15. Known limits

- The band has **one EMG channel**, so only the biceps glows; the triceps highlight is built but never switched on.
- The muscle areas are **painted by anatomy rules** (front and back, between elbow and shoulder), not taken from a detailed muscle model.
- It follows **one joint, the elbow**. Shoulder and wrist are not tracked.
- The 3D view needs WebGL in the phone's WebView; where it is missing, the flat 2D arm is used.
- Home's static model is not tied to the patient's side.
