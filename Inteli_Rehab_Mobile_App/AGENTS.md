# AGENTS.md — Inteli-Rehab Engineering & Design Constitution

This document defines the strict development standards for all automated and paired AI coding agents working in `Inteli_Rehab_Mobile_App`. Every rule here exists because of real bugs, architecture issues, or clinical requirements.

Complementary documents:
- `docs/coding-standards.md` — Core architecture, naming, git discipline.
- `docs/hci-security-standards.md` — Human-Computer Interaction, accessibility, and security guidelines.
- `docs/frontend-engineering-standards.md` — Flutter frontend smell catalog, container vs. presentational widgets, real-time IoT/BLE rules, 3D rendering, and AI-driven UI rules.

---

## 1. Core Architecture & Layers

- **Feature Structure**: Every feature maintains three strict layers:
  - `domain/`: Entities, repository interfaces (pure Dart, zero Flutter/Supabase imports).
  - `data/`: Data models, datasources, and repository implementations (`*RepositoryFake` and `*RepositoryImpl`).
  - `presentation/`: Screens, widgets, state management (BLoC/Cubit), and pure validators.
- **Dependency Injection**:
  - All repositories are registered in `lib/core/di/injection.dart` using `GetIt` (`sl`).
  - The fake/real repository pattern must be preserved until backend services are integrated and verified by Tehreem.
- **Canonical Model Locations**:
  - Domain entities shared across 2+ features (patient, clinic, therapist, exercise, session) live in `lib/shared/entities/`.
  - Feature-specific entities live in `lib/features/<feature>/domain/entities/`.
- **Search First, Create Second**: Always search the codebase for existing widgets, models, and screens before creating new ones. Never introduce duplicates.

---

## 2. Shared Inteli-Rehab Palette & Theme Standards

### LIGHT MODE FIRST POLICY
- Design and build **all screens in light mode first**. Dark mode comes after the full set of screens is complete.
- For Stitch: Design only the light-mode version. Do not create dark-mode frames, theme toggles, or “Dark Mode Sync” labels. Use our agreed light palette: background `#F5F8F7`, white cards, primary teal `#0D6E76`, headings `#093D42`, and body text `#12242B`. Keep colors centralized so we can add dark mode later. Remove “Dark Mode Sync.”

Screens must reference semantic theme colors centrally defined in `AppTheme.colors(context)` (`AppThemeColors`) instead of hardcoding raw hex values.

### LIGHT THEME (PRIMARY FOCUS)
- **Page background**: `#F5F8F7`
- **Cards and input surfaces**: `#FFFFFF`
- **Primary buttons and links**: `#0D6E76`
- **Button text**: `#FFFFFF`
- **Headings**: `#093D42`
- **Body text**: `#12242B`
- **Secondary text**: `#4C6360`
- **Borders**: `#DEE7E5`
- **Soft teal information surfaces**: `#E4F1F0`
- **Text on information surfaces**: `#093D42`

### DARK THEME
- **Page background**: `#0B2023`
- **Cards and input surfaces**: `#102F32`
- **Primary buttons and links**: `#31E8C6` (bright mint)
- **Text on mint buttons**: `#093D42` (dark text on bright mint buttons for readability!)
- **Headings and body text**: `#F1F7F6`
- **Secondary text**: `#B6CBC8`
- **Borders**: `#365356`
- **Soft teal information surfaces**: `#163E3D`
- **Text on information surfaces**: `#C4F5EA`

### ERROR STATES
- **Light**: Text `#B3261E` on background `#FCE8E6`
- **Dark**: Text `#FFB4AB` on background `#4A2020`
- **Rule**: Always include a readable message and icon; never communicate errors using color alone.

### WCAG AA CONTRAST & CONTROL BOUNDARIES
- Contrast ratios: at least **4.5:1** for normal text and **3:1** for large text and meaningful control boundaries.
- Give input fields clearly visible boundaries (`width: 1.5`) and a stronger focus outline (`width: 2.0` in primary color) rather than relying on faint borders alone.
- Follow system theme using `ThemeMode.system` and respect existing user preferences.
- Preserve the existing splash design.

---

## 3. Frontend Code Smell Catalog & Quality Gate

- **No God Widgets**: `build()` methods must stay under ~100–150 lines. Extract visually distinct pieces into named presentational widgets.
- **Smart vs. Dumb Split**:
  - `*_screen.dart` files are smart containers (know about Cubit/Bloc, navigation, repository calls).
  - Reusable components (`shared/widgets/` and feature presentation subwidgets) are dumb/presentational widgets (pure functions of constructor parameters, zero backend or DI imports).
- **No Magic Numbers**: No raw `Color(0xFF...)` or magic layout constants in screens. Reference `AppTheme.colors(context)` or theme extensions.
- **No Business Logic in Widgets**: Keep calculations, rep validation, and domain decisions inside usecases, BLoCs, or pure validators.
- **Every Controller Disposed**: All `AnimationController`, `TextEditingController`, and `StreamSubscription` instances must have an explicit matching `dispose()`.
- **Narrow Real-Time Stream Scoping**: Do not call full-screen `setState()` on high-frequency BLE streams; wrap only the changing leaf widget with `ValueListenableBuilder` or targeted `StreamBuilder`.
- **Validate & Clamp Sensor Data**: Never render raw impossible values (e.g. 400° ROM). Show explicit signal-loss states when BLE disconnects.

---

## 4. Security, Privacy & Session Management

- **Data Privacy**:
  - Treat all rehabilitation data as sensitive Protected Health Information (PHI).
  - Never log credentials, names, emails, or session metrics via `print()` or `debugPrint()`.
- **Authentication**:
  - Validate inputs locally: trim and lowercase email, leave passwords unmodified.
  - Generic authentication errors only (e.g. "Invalid email or password"). Never reveal whether an account exists.
  - Clear passwords from memory and controllers immediately on success and on failure.
  - OS Autofill hints and accessible visibility toggles enabled on password fields.
- **Session Expiry**:
  - 30-minute inactivity session expiry enforced consistently.
  - Re-verify session expiry upon app resume (`AppLifecycleState.resumed`).
  - Completely clear sensitive in-memory state on sign-out or session expiration.
- **Frontend Previews**:
  - Clearly label preview modes as frontend previews.
  - Do not persist fake credentials or fake accounts to remote backends.
  - Guard fake repository authentication from being used in production release builds (`kReleaseMode`).

---

## 5. Coding & Git Discipline

- **No Spaces in File Names**: All filenames must be `snake_case` (e.g. `patient_entity.dart`, `thin_line.png`).
- **Asset Match**: Exact-match spelling and case between disk, `pubspec.yaml`, and code references.
- **4 Explicit States**: Every data screen must handle Loading, Error, Empty, and Success states.
- **No Direct Push or Unprompted Commits**: Do not commit or push unless explicitly requested by the user. Preserve existing uncommitted work.
- **Zero Analyzer Errors**: Run `flutter analyze` before completing any task. Must report 0 errors and 0 warnings.
