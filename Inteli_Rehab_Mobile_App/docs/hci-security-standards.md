# Inteli-Rehab — App-Wide HCI, Security & Coding Standards



Covers every screen and feature, not just one. Paste the relevant section into any Antigravity prompt. This complements `docs/coding-standards.md` (naming, architecture, git discipline) — that document stays focused on code structure; this one covers user experience and safety.



---



## PART 1 — HCI Principles (Whole App)



### General principles, every screen



1. **Visibility of system status** — any action that takes >300ms (network call, BLE operation, save) shows a loading state. The patient should never wonder "did that work?"

2. **Error prevention over error correction** — disable a submit button until required fields are valid, rather than letting the patient submit and then telling them what's wrong. Where correction is unavoidable, the error message must say exactly what to fix.

3. **Consistency across the whole app** — same teal palette, same fonts (Sora for headings, Manrope for body), same button shapes and spacing rhythm on every screen. A patient shouldn't have to relearn the interface between screens.

4. **Recognition over recall** — never require the patient to remember information from a previous screen without showing it again (e.g. re-display the injury/joint being treated during a session, don't assume they remember what they selected weeks ago).

5. **Minimal cognitive load per screen** — one primary action per screen. If a screen has more than one equally-weighted button, that's a sign it's doing too much.

6. **Forgiving input everywhere** — trim whitespace, accept case-insensitive email, don't crash or silently fail on unexpected input; show a specific correction instead.



### Accessibility for this specific patient population



Your SRS (USE-1 to USE-4) explicitly targets older adults and non-technical users recovering from injury — take this seriously, it's not boilerplate:



- **Minimum 48×48dp touch targets** on every interactive element, everywhere in the app, no exceptions

- **16sp minimum body text**, 14sp absolute floor for secondary/caption text — never smaller

- **Color is never the only signal.** The digital twin's color-coded muscle activation (blue→green→orange→red) needs a secondary cue too — an icon, a label, a pattern — for colorblind patients. This is explicitly in your SRS (BR-12 area) — don't skip it.

- **Voice guidance during live sessions is a genuine accessibility feature**, not a nice-to-have — a patient exercising with their eyes on their arm, not their phone, needs audio cues for corrections and rep counts.

- **One-handed operation matters** — a patient with an injured arm may be operating the phone one-handed. Keep primary actions reachable in the lower half of the screen where possible.



### Context-specific HCI rules



**Onboarding (Splash/Video/Logo/Auth):** Keep it brief and skippable where reasonable — a patient in pain waiting through unskippable animations before they can log in is a real usability failure, not just an aesthetic one.



**Wearable connection & calibration:** This is the most physically fiddly part of the app for a patient. Every instruction must be paired with a visual diagram (you already have this in your calibration mockup). Never let a patient feel stuck — always show a clear "retry" or "get help" path, never a dead-end error.



**Live rehab session (digital twin, rep counter, alerts):** Corrective feedback must feel *helpful*, never alarming. A fatigue warning is guidance, not a failure notice — tone matters (e.g. "Let's take a short break" not "ERROR: Fatigue threshold exceeded"). Alerts interrupt gently (a soft visual + optional voice cue), never with jarring sounds or modal dialogs that block the exercise mid-motion unless safety genuinely requires a hard stop.



**Progress & gamification:** Positive reinforcement only. A missed session or a bad rep should never be presented as a failure or produce shame-based messaging — the tone should always assume the patient is trying, and gently redirect. This matters clinically, not just stylistically — discouraged patients disengage from rehab entirely.



**Empty states:** Every "no data yet" screen (no sessions yet, no plan assigned yet) should explain *why* and *what happens next* — never just a blank screen or a bare "No data."



---



## PART 2 — Security Rules (Whole App)



### Data classification — treat this like real health data, because it is



Injury details, session metrics, muscle activation data, and movement patterns are all sensitive personal health information, even though this is a student project. Design every screen as if it were handling real patient records — because functionally, it is.



### Backend & data access



1. **RLS on every table with a patient_id or physiotherapist_id column** — no exceptions, confirmed before that table is used by any screen (see SRS SEC-1, BR-16).

2. **Role-based access is enforced at the data layer, never just hidden in the UI.** A hidden button is not security — if a patient-role account could technically call a physiotherapist-only function and it would succeed, that's a real vulnerability regardless of what the UI shows.

3. **Data minimization** — a screen only fetches the fields it actually displays. Don't `select('*')` out of convenience when the screen uses three columns.

4. **Never trust client-side validation as the real boundary** — it's UX polish. The actual enforcement is Supabase RLS and server-side checks.



### Secrets & credentials



5. **Never hardcode Supabase URL/keys in source** — `.env`, gitignored, always.

6. **Never commit `.env`, tokens, or anything matching a credential pattern** — verify with `git status`/`git diff` before every push, not after.

7. **The `service_role` key never touches the Flutter app** — client-side only ever uses the `anon` key, protected by RLS.



### On-device storage & session handling



8. **Auth tokens and any cached patient data use `flutter_secure_storage`**, never plain `SharedPreferences` — this includes offline-cached session data (per your offline-first requirement).

9. **Session expiry after 30 minutes of inactivity** (SEC-3) is enforced consistently — `AuthGate` and every screen agree on this, no screen silently bypasses it.

10. **Clear sensitive in-memory state on logout** — don't let a previous patient's cached data linger in memory or local storage after sign-out on a shared device.



### Networking & hardware



11. **HTTPS only, no cleartext traffic** — Supabase enforces this by default; don't override it for convenience during testing and forget to revert.

12. **BLE pairing only accepts your expected device signature** (service UUID / device name pattern) — don't let the app silently pair with or accept data from an unrecognized nearby BLE device, which could misattribute sensor data to the wrong session.



### Logging & error handling



13. **Never log patient data** (name, injury, email, session metrics) via `print()`/`debugPrint()` in code that could reach a release build.

14. **Error messages shown to the patient never leak internal details** — no raw exception text, stack traces, or database error strings surfaced in the UI. Log those internally (safely, without PHI) for debugging, show the patient a plain, honest, non-technical message instead.

15. **Generic auth failure messages** — "Incorrect email or password," never confirming which part was wrong or whether an email exists in the system.



---



## PART 3 — Coding Best Practices (Whole App)



*(This section is a whole-app companion to `docs/coding-standards.md` — see that file for naming conventions, architecture layering, and the fake/real repository pattern in full detail. Below are the app-wide practices not yet covered there.)*



### Performance-critical code



1. **Heavy computation never runs on the UI thread.** Sensor fusion (Madgwick/EKF filtering), EMG feature extraction, and AI inference all run in an `Isolate` or `compute()` call — your SRS's PER-2 (10ms digital twin update latency) is not achievable if this math blocks the main thread.

2. **Throttle high-frequency BLE data** before it reaches the UI layer — don't call `setState()` on every single raw sensor packet; batch or debounce updates to a sane render rate (e.g. 30-60fps equivalent), or the UI will visibly stutter regardless of how fast the underlying computation is.



### Offline-first data handling



3. **Write to local storage first, sync to Supabase second** — this is the pattern for anything generated during a live session (per Module 9's offline-first requirement). A screen that writes directly to Supabase first, with local storage as an afterthought, will lose data the moment connectivity drops mid-session.

4. **Handle sync conflicts explicitly, don't ignore them** — if a session was recorded offline and the app later finds a conflicting or duplicate record on sync, that needs a defined resolution (e.g. last-write-wins with a timestamp check), not silent overwriting or silent data loss.



### State completeness



5. **Every data-loading screen has all four states**: loading, error, empty, success — already a rule in `coding-standards.md`, repeated here because it's this important. This is the single most common cause of a screen that "works in testing" but breaks during a live demo.



### Testing discipline



6. **New business logic (usecases, repository logic, signal-processing functions) gets a unit test at the same time it's written**, not retrofitted later — matches the `test/` folder mirroring `lib/` structure already set up.

7. **Test the unhappy paths deliberately**: BLE disconnects mid-session, calibration with excessive movement, offline session completion, RLS boundary attempts (can Patient A ever see Patient B's data) — these are explicitly called out in your SRS's alternative flows and business rules; don't just test the happy path and assume the rest works.



### Code review checklist (for Antigravity or a human reviewer)



Before merging any new screen or feature:

- [ ] No duplicate entities/widgets/screens created (searched first)

- [ ] All four data states handled (loading/error/empty/success)

- [ ] No hardcoded secrets, no logged PII/PHI

- [ ] Touch targets ≥48dp, text ≥16sp body / 14sp caption minimum

- [ ] Heavy computation off the UI thread

- [ ] `flutter analyze` clean, zero errors

- [ ] Matches existing teal palette / typography, no visual inconsistency introduced



---



Keep this file at `docs/hci-security-standards.md`, alongside `docs/coding-standards.md`. Reference both explicitly in prompts: *"Follow docs/coding-standards.md and docs/hci-security-standards.md for this task."*
