import { useState, useEffect } from "react";
import { THEME } from "../../../infrastructure/physio/constants";
import { SectionHead, Card } from "../components";
import ExerciseUseCases from "../../../domain/physio/usecases/ExerciseUseCases";
import VisualizationService from "../../../infrastructure/physio/services/VisualizationService";
import { pagePadding } from "../components/chartTheme";
import useIsMobile from "../../useIsMobile";
import ErrorNotice from "../../ErrorNotice";

function ExercisesPage() {
  const [exercises, setExercises] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [reloadKey, setReloadKey] = useState(0);
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState("All");
  const levels = ExerciseUseCases.getDifficultyLevels();
  const isMobile = useIsMobile();

  useEffect(() => {
    let mounted = true;
    setLoading(true);
    setError(null);
    ExerciseUseCases.getAllExercises()
      .then((data) => {
        if (mounted) setExercises(data);
      })
      .catch(() => {
        if (!mounted) return;
        setExercises([]);
        setError("Couldn't load the exercise database.");
      })
      .finally(() => {
        if (mounted) setLoading(false);
      });
    return () => {
      mounted = false;
    };
  }, [reloadKey]);

  const filtered = ExerciseUseCases.filterExercises(exercises, filter, search);

  return (
    <div style={{ padding: pagePadding(isMobile) }}>
      <SectionHead
        title="Exercise database"
        sub={loading ? "Loading…" : `${exercises.length} clinic-approved exercises`}
        action={
          <div style={{ display: "flex", flexWrap: "wrap", gap: 10 }}>
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
                background: THEME.surface,
                outline: "none",
                width: isMobile ? "100%" : 200,
                boxSizing: "border-box",
              }}
            />
            <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
              {levels.map((l) => (
                <button
                  key={l}
                  onClick={() => setFilter(l)}
                  style={{
                    padding: "8px 14px",
                    borderRadius: 9,
                    border: `1px solid ${filter === l ? THEME.teal : THEME.slate200}`,
                    background: filter === l ? THEME.tealLight : THEME.surface,
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
      <ErrorNotice message={error} onRetry={() => setReloadKey((k) => k + 1)} />
      {!loading && !error && exercises.length === 0 && (
        <Card style={{ padding: "32px 24px", textAlign: "center", marginBottom: 16 }}>
          <div style={{ fontSize: 15, fontWeight: 600, color: THEME.slate800, marginBottom: 6 }}>
            No exercises in the database yet
          </div>
          <div style={{ fontSize: 13, color: THEME.slate400 }}>
            Ask your administrator to load the exercise dataset (supabase_seed_exercises.sql).
          </div>
        </Card>
      )}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fill, minmax(min(100%, 260px), 1fr))",
          gap: isMobile ? 12 : 16,
        }}
      >
        {filtered.map((ex) => (
          <Card key={ex.id} style={{ padding: isMobile ? "18px 16px" : "20px 22px" }}>
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
        {!loading && filtered.length === 0 && (
          <div
            style={{
              gridColumn: "1/-1",
              padding: 40,
              textAlign: "center",
              color: THEME.slate400,
              fontSize: 13,
            }}
          >
            {exercises.length === 0 ? "No exercises in the catalogue yet." : "No exercises match your search."}
          </div>
        )}
      </div>
    </div>
  );
}

export default ExercisesPage;
