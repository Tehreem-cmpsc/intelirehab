# Inteli-Rehab — Coding Standards & Best Practices

Paste this into any Antigravity prompt when building a new screen or feature. Every rule here exists because of a real bug or real mess we already hit in this project — not theoretical advice.

---

## 1. Before creating ANY new file or class

**Search first, create second.** Before writing a new entity, widget, model, or screen, check whether something with the same purpose already exists — in `shared/`, in another feature's folder, or under a different name. This project has already had duplicate `RegisterScreen` classes and duplicate `PatientProfile`/`PatientEntity` models from skipping this step. The rule: if Antigravity is about to create `X`, it first searches the codebase for anything already doing `X`'s job.

**One class, one canonical location.** A concept used by 2+ features (patient, clinic, physiotherapist, exercise, session) lives in `lib/shared/entities/` — nowhere else. A concept used by exactly one feature lives inside that feature's own `domain/entities/`. Never both.

---

## 2. Naming — exact-match discipline (this has broken the app twice already)

**No spaces in any filename, ever.** Not asset files, not Dart files. Use `snake_case` for everything: `thin_line.png`, `patient_entity.dart`, `home_dashboard_screen.dart`. A filename with a space (`thin line.png`) referenced without the space in code will silently work on Chrome/desktop and silently fail on a real Android device — this exact bug has already happened in this project twice.

**Match case and spelling character-for-character between:**
- The actual file on disk
- The `pubspec.yaml` declaration (if listed individually)
- Every `Image.asset()` / `VideoPlayerController.asset()` call referencing it

Before adding any new asset reference, copy the filename directly from the file explorer — never type it from memory.

**Dart naming conventions:**
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/functions: `camelCase`
- Private members: `_leadingUnderscore`
- Repository interfaces: `<Feature>Repository` (abstract)
- Fake implementations: `<Feature>RepositoryFake`
- Real implementations: `<Feature>RepositoryImpl`
- BLoC: `<Feature>Bloc` + `<Feature>Event` + `<Feature>State`
- Cubit (simpler features): `<Feature>Cubit` + `<Feature>State`

---

## 3. Architecture rules

**Every feature keeps its three layers separate:** `data/` (models, datasources, repository implementations), `domain/` (entities, repository interfaces, usecases — pure Dart, zero Flutter or Supabase imports), `presentation/` (screens, widgets, state management). A screen never calls Supabase directly — it goes through a repository interface. (Exception: if a feature genuinely doesn't need this — e.g. `auth` ended up using a direct `AuthService` instead of the full Bloc scaffold — that's fine, but the unused scaffold gets deleted, not left sitting alongside the real code. Don't maintain two parallel systems for the same job.)

**The fake/real repository pattern stays until a feature is actually backend-complete.** Every feature not yet wired to real Supabase data uses a `*_repository_fake.dart` returning clearly-fake placeholder data — never hardcode fake values directly inside a screen or Bloc. This keeps the swap to real data a one-line change in `core/di/injection.dart`, never a screen rewrite.

**No dead code left "just in case."** If a class, file, or whole architecture layer is genuinely unused (confirmed by searching the full codebase for references), delete it. Don't comment it out "for later" — this project has already had two files (`video_intro_screen.dart`, `logo_reveal_screen.dart`) that were entirely commented out and silently did nothing for a full session before anyone noticed. If something might be needed later, that's what git history is for.

---

## 4. State handling

**Every screen that loads data needs four explicit states:** loading, error, empty (e.g. "no exercise plan assigned yet"), and success. A screen that only handles the happy path will crash or hang silently the first time the network drops or a query returns nothing — this is the #1 cause of live-demo failures.

**Never leave a screen with no feedback during an async action.** Every button that triggers a network call needs a loading indicator and disables itself while in flight (see `login_screen.dart`'s `_submitting` pattern — that's the standard to follow everywhere).

---

## 5. Security (non-negotiable, not optional polish)

- Never hardcode a Supabase URL or key directly in source — always `.env`, always gitignored
- Never log patient data (name, injury, session metrics) via `print()`/`debugPrint()` in anything that could ship to release
- Auth tokens and any cached patient data stored locally use `flutter_secure_storage`, never plain `SharedPreferences`
- Every new Supabase table needs a Row Level Security policy before it's used — no table goes live without one, even a demo/test one

---

## 6. Git & commit discipline

- One logical change per commit — don't bundle a new screen with an unrelated bug fix
- Commit messages describe *what* and *why* in one line: `"Fix asset filename mismatch causing invisible splash logo on Android"`, not `"fix stuff"`
- Before pushing: run `flutter analyze` and confirm zero errors
- Never commit `.env`, API keys, or anything matching a credential pattern — double-check `git status` before every push
- Feature branches per screen/feature, PR into `main`, not direct pushes to `main`

---

## 7. Comments — explain *why*, not *what*

A comment restating what the code obviously does is noise. A comment explaining a non-obvious decision is valuable. Example of a good comment already in this codebase:
```dart
// NOTE: auth is no longer registered here — it now uses a direct
// AuthService wired straight to Supabase, since that's how it was
// actually integrated.
```
That's the standard — it tells a future reader (including you, in three weeks) *why* something looks the way it does, preventing them from "fixing" it back into a duplicate.

---

## 8. When Antigravity finishes a task

Before reporting a task done, it should confirm:
1. `flutter analyze` shows zero errors
2. No new duplicate files or classes were created (search performed, documented)
3. No new asset reference was added without confirming the exact on-disk filename
4. Any new feature follows the fake/real repository split if backend isn't ready
5. A one-line summary of what changed and why — not just "done"
