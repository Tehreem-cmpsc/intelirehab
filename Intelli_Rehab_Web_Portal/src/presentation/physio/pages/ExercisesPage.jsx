import { useState } from "react";
import { THEME } from "../../../infrastructure/physio/constants";
import { SectionHead, Card } from "../components";
import ExerciseUseCases from "../../../domain/physio/usecases/ExerciseUseCases";
import VisualizationService from "../../../infrastructure/physio/services/VisualizationService";

function ExercisesPage() {
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState("All");
  const levels = ExerciseUseCases.getDifficultyLevels();
  const filtered = ExerciseUseCases.filterExercises(filter, search);
  // THEME.white is intentionally the same literal #FFFFFF in both palettes
  // (e.g. white text on a colored badge) — it's the wrong choice for a
  // surface/background color, which needs to actually change in dark mode.
  const isDark = typeof document !== "undefined" && document.documentElement.getAttribute("data-theme") === "dark";

  return (
    <div style={{ padding: "28px 32px" }}>
      <SectionHead
        title="Exercise database"
        sub={`${ExerciseUseCases.getTotalExerciseCount()} clinic-approved exercises`}
        action={
          <div style={{ display: "flex", gap: 10 }}>
            <input
              placeholder="Search exercises…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              style={{
                padding: "9px 14px",
                border: `1.5px solid ${THEME.slate200}`,
                borderRadius: 9,
                fontSize: 13,
                color: THEME.slate800,
                background: isDark ? THEME.slate100 : THEME.white,
                outline: "none",
                width: 200,
              }}
            />
            <div style={{ display: "flex", gap: 6 }}>
              {levels.map((l) => (
                <button
                  key={l}
                  onClick={() => setFilter(l)}
                  style={{
                    padding: "8px 14px",
                    borderRadius: 9,
                    border: `1px solid ${filter === l ? THEME.teal : THEME.slate200}`,
                    background: filter === l ? THEME.tealLight : (isDark ? THEME.slate100 : THEME.white),
                    color: filter === l ? THEME.tealDim : THEME.slate600,
                    fontSize: 12,
                    fontWeight: filter === l ? 700 : 400,
                    cursor: "pointer",
                  }}
                >
                  {l}
                </button>
              ))}
            </div>
          </div>
        }
      />
      <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 16 }}>
        {filtered.map((ex) => (
          <Card key={ex.id} style={{ padding: "20px 22px" }}>
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "flex-start",
                marginBottom: 10,
              }}
            >
              <div
                style={{
                  fontSize: 15,
                  fontWeight: 700,
                  color: THEME.slate800,
                  lineHeight: 1.3,
                }}
              >
                {ex.name}
              </div>
              <span
                style={{
                  background: VisualizationService.getDifficultyBg(ex.difficulty),
                  color: VisualizationService.getDifficultyColor(ex.difficulty),
                  fontSize: 11,
                  fontWeight: 600,
                  padding: "3px 9px",
                  borderRadius: 8,
                  flexShrink: 0,
                  marginLeft: 8,
                }}
              >
                {ex.difficulty}
              </span>
            </div>
            <div
              style={{
                fontSize: 12,
                color: THEME.tealDim,
                fontWeight: 600,
                marginBottom: 8,
              }}
            >
              Target: {ex.target}
            </div>
            <div
              style={{
                fontSize: 13,
                color: THEME.slate500,
                lineHeight: 1.5,
              }}
            >
              {ex.desc}
            </div>
          </Card>
        ))}
        {filtered.length === 0 && (
          <div
            style={{
              gridColumn: "1/-1",
              padding: 40,
              textAlign: "center",
              color: THEME.slate400,
              fontSize: 13,
            }}
          >
            No exercises match your search.
          </div>
        )}
      </div>
    </div>
  );
}

export default ExercisesPage;
