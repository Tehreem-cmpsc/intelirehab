# Thesis class diagrams: mobile and web

Two class diagrams, written from the source code (names, attributes and operations are the real ones).

| Diagram | Covers | Written from |
|---|---|---|
| `class_diagram_mobile` | The Flutter app: navigation and sign-up, guided calibration, band communication, live session, rep assessment (trained model and safety rules), offline data and sync, 3D digital twin | `Inteli_Rehab_Mobile_App/lib/` |
| `class_diagram_web` | The React portal: screens, hooks, use cases, entities, repository and its link to Supabase | `Intelli_Rehab_Web_Portal/src/` |

## Files

- `class_diagram_*.puml` - PlantUML source (edit these).
- `svg/` - vector images. Use these in the thesis: they stay sharp at any size, and in a PDF you can zoom in.
- `png/` - 200 dpi images, for programs that cannot take SVG.
- `detailed/` - the same system split into ten smaller figures (system overview, domain model, armband firmware, and
  seven finer-grained mobile and web figures). Use them as an appendix, or to show one area at a readable size.

## Using them on a page

Both diagrams show only the main classes, with straight (orthogonal) lines and no notes or external boxes.
Mobile is about 2750 x 1340 px and web about 1640 x 1440 px at 200 dpi, so mobile suits a landscape page and web a
portrait or half page. For finer detail (supporting classes, enumerations, firmware) use the figures in `detailed/`.

## Notation (state once in the thesis)

- A box has three parts: name (with an optional stereotype in guillemets), attributes, operations.
  `+` public, `-` private, underlined = static.
- Solid line with a **filled** diamond: composition (the whole owns the part). **Hollow** diamond: aggregation.
- Solid arrow: the source holds a reference to the target (association). Dashed arrow with a label such as
  `<<create>>` or `<<use>>`: dependency.
- Hollow triangle: generalisation (solid) or realisation of an interface (dashed).
- Numbers at line ends are multiplicities (`1`, `0..1`, `0..*`).
- Stereotypes name a class's role: `<<screen>>`, `<<interface>>`, `<<enumeration>>`, `<<entity>>`, `<<external>>`.

## What the diagrams leave out

- Only the main classes are drawn. Supporting classes (services for auth, the exception hierarchy, the reconnect
  timer, the plan summary, fatigue estimator, session simulator, UI widgets, enumerations) are in `detailed/`.
- Web: `PhysioPages`, `AdminPanels` and `Hooks` each stand for a group of React components or hooks; the Supabase
  client is used by every use case, repository and hook, so only one line to it is drawn.
- Operations with long parameter lists are shortened to `(...)`.
- The red safety limits are placeholders until a physiotherapist sets them, and the rep model (`ElbowAutoencoder`)
  has so far been tested on Kinect data, not armband data.

## Re-rendering

Needs Java and PlantUML, and Graphviz for the best layout. The mobile diagram is wider than PlantUML's default
limit, so raise it:

    set PLANTUML_LIMIT_SIZE=20000
    java -jar plantuml.jar -tsvg -o svg class_diagram_mobile.puml class_diagram_web.puml
    java -jar plantuml.jar -tpng -o png class_diagram_mobile.puml class_diagram_web.puml

If a class changes in the code, change it in the matching `.puml` too; the diagrams are only as accurate as the last
time someone compared them with the source.
