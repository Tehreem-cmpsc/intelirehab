# Detailed class diagrams (appendix set)

Ten smaller figures that split the system by area. The two main diagrams are one level up (`class_diagram_mobile`,
`class_diagram_web`); use these when a figure must be shown at a readable size.

Ten focused UML class diagrams, written from the source code (names, attributes and operations are the real ones).
Each fits one page; together they cover the whole system. Grayscale, so they print cleanly.

| Figure | Shows | Source it was written from |
|---|---|---|
| 1 | System overview: the five subsystems and their interfaces | whole repository |
| 2 | Domain model: persistent classes and associations (multiplicities) | `Intelli_Rehab_Web_Portal/supabase_*.sql` |
| 3 | Armband firmware classes | `firmware/lib/ArmEMG_IMU/` |
| 4 | Mobile app: communication with the armband | `lib/features/home/ble/`, `wearable_connection_controller.dart` |
| 5 | Mobile app: sign-up, routing, guided calibration | `lib/app.dart`, `lib/features/onboarding/` |
| 6 | Mobile app: live exercise session | `lib/features/exercises/` |
| 7 | Mobile app: rep assessment (trained model, amber; safety rules, red) | `lib/features/exercises/processing/` |
| 8 | Mobile app: exercise plan, offline-first storage and upload | `exercises_repository.dart`, `session_journal.dart` |
| 9 | Mobile app: live 3D digital twin | `lib/features/twin/`, `assets/twin/` |
| 10 | Web portal: layered structure | `Intelli_Rehab_Web_Portal/src/` |

## Files

- `figNN_*.puml` - the PlantUML source (edit these).
- `svg/` - vector images: use these in the thesis (sharp at any size, text stays selectable).
- `png/` - 200 dpi images, for programs that cannot take SVG.

## Notation (state this once in the thesis)

- A box has three parts: name (with an optional stereotype in guillemets), attributes, operations.
  `+` public, `-` private, underlined = static.
- Solid line with a **filled** diamond: composition (the whole owns the part). **Hollow** diamond: aggregation.
- Solid arrow: the source holds a reference to the target (association). Dashed arrow with a label such as
  `<<create>>` or `<<use>>`: dependency.
- Hollow triangle: generalisation (solid) or realisation of an interface (dashed).
- Numbers at line ends are multiplicities (`1`, `0..1`, `0..*`).
- Stereotypes name the role of a class: `<<screen>>`, `<<interface>>`, `<<enumeration>>`, `<<asset>>`,
  `<<subsystem>>`, `<<entity>>`.

## Choices worth mentioning in the text

- **Figure 2** is the data model as UML. A `Session` with no `Exercise` is the sign-up calibration baseline.
  Two associations from `Physiotherapist` (assigning exercises, acknowledging alerts) are given in a note instead
  of drawn, to keep the figure readable.
- **Figure 7** is the part that uses the trained model. `ElbowRepChecker` (amber) judges each rep after it ends;
  `SafetyMonitor` (red) watches every sample live and can stop the session; `RepAssessor` is the simple fallback
  used only if the model file cannot be loaded. The red limits in `SafetyLimits` are placeholders awaiting a
  physiotherapist's values.
- Pure UI widgets, painters and small private helper classes are left out; only the screens that drive a flow
  appear.

## Re-rendering

Needs Java and PlantUML (and Graphviz for the best layout):

    java -jar plantuml.jar -tsvg figNN_*.puml
    java -jar plantuml.jar -tpng figNN_*.puml

If a class changes in the code, change it in the matching `.puml` too; the figures are only as accurate as the
last time someone compared them with the source.
