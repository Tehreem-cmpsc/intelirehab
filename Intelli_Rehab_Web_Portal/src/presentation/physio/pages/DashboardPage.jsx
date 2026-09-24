import { THEME } from "../../../infrastructure/physio/constants";
import {
  ResponsiveContainer,
  AreaChart,
  BarChart,
  CartesianGrid,
  XAxis,
  YAxis,
  Tooltip,
  Area,
  Bar,
} from "recharts";
import {
  SectionHead,
  Card,
  RomBar,
  Badge,
} from "../components";
import VisualizationService from "../../../infrastructure/physio/services/VisualizationService";
import { computeWeeklyRom, computeWeekdayActivity } from "../../../domain/physio/utils/sessionAnalytics";

function DashboardPage({ patients = [], setPage, setSelectedPatientId }) {
  // Every patient's sessions were already fetched once in PatientUseCases —
  // reuse that instead of a second clinic-wide query.
  const allSessionsAsc = [...patients.flatMap((p) => p.sessions)].sort(
    (a, b) => a.performedAt - b.performedAt
  );
  const romData = computeWeeklyRom(allSessionsAsc).map((w) => ({ week: w.w, avg: w.v }));
  const actData = computeWeekdayActivity(allSessionsAsc);
  const hasSessionData = allSessionsAsc.length > 0;

  const todayKey = new Date().toDateString();
  const sessionsToday = allSessionsAsc.filter((s) => s.performedAt.toDateString() === todayKey).length;

  const approvedPatients = patients.filter((p) => p.approved);
  const pendingCount = patients.filter((p) => p.isPendingApproval()).length;
  const atRiskCount = patients.filter((p) => p.isAtRisk()).length;

  const stats = [
    {
      label: "Total Patients",
      value: approvedPatients.length,
      sub: "Approved patients",
      color: THEME.teal,
      bg: THEME.tealLight,
    },
    {
      label: "Sessions Today",
      value: sessionsToday,
      sub: hasSessionData ? "Logged today" : "No sessions logged yet",
      color: THEME.green,
      bg: THEME.greenLight,
    },
    {
      label: "Pending Approvals",
      value: pendingCount,
      sub: "Awaiting review",
      color: THEME.amber,
      bg: THEME.amberLight,
    },
    {
      label: "At Risk",
      value: atRiskCount,
      sub: "Needs attention",
      color: THEME.red,
      bg: THEME.redLight,
    },
  ];

  return (
    <div style={{ padding: "28px 32px" }}>
      <SectionHead
        title="Overview"
        sub="Wednesday, 25 June 2026 · Good morning, Dr. Khan"
      />

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(4,1fr)",
          gap: 16,
          marginBottom: 24,
        }}
      >
        {stats.map((s) => (
          <Card
            key={s.label}
            style={{ padding: "20px 22px", display: "flex", gap: 14, alignItems: "flex-start" }}
          >
            <div
              style={{
                width: 42,
                height: 42,
                borderRadius: 11,
                background: s.bg,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                flexShrink: 0,
              }}
            >
              <div
                style={{
                  width: 16,
                  height: 16,
                  borderRadius: "50%",
                  background: s.color,
                }}
              />
            </div>
            <div>
              <div style={{ fontSize: 26, fontWeight: 800, color: THEME.slate800, lineHeight: 1.1 }}>
                {s.value}
              </div>
              <div style={{ fontSize: 13, color: THEME.slate600 }}>{s.label}</div>
              <div style={{ fontSize: 11, color: THEME.slate400, marginTop: 3 }}>
                {s.sub}
              </div>
            </div>
          </Card>
        ))}
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1.5fr 1fr", gap: 20, marginBottom: 24 }}>
        <Card style={{ padding: "22px 24px" }}>
          <div style={{ fontSize: 15, fontWeight: 700, color: THEME.slate800, marginBottom: 4 }}>
            Average ROM trend
          </div>
          <div style={{ fontSize: 12, color: THEME.slate400, marginBottom: 18 }}>
            All active patients · last {romData.length || 6} weeks with sessions
          </div>
          {romData.length === 0 ? (
            <div
              style={{
                height: 170,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                fontSize: 13,
                color: THEME.slate400,
              }}
            >
              No session data yet.
            </div>
          ) : (
            <ResponsiveContainer width="100%" height={170}>
              <AreaChart data={romData} margin={{ top: 5, right: 5, bottom: 0, left: -20 }}>
                <defs>
                  <linearGradient id="rg" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor={THEME.teal} stopOpacity={0.2} />
                    <stop offset="95%" stopColor={THEME.teal} stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke={THEME.slate100} />
                <XAxis
                  dataKey="week"
                  tick={{ fontSize: 11, fill: THEME.slate400 }}
                  axisLine={false}
                  tickLine={false}
                />
                <YAxis
                  tick={{ fontSize: 11, fill: THEME.slate400 }}
                  axisLine={false}
                  tickLine={false}
                  domain={[0, 100]}
                />
                <Tooltip
                  contentStyle={{
                    borderRadius: 9,
                    border: `1px solid ${THEME.slate200}`,
                    fontSize: 12,
                  }}
                  formatter={(v) => [`${v}%`, "Avg ROM"]}
                />
                <Area
                  type="monotone"
                  dataKey="avg"
                  stroke={THEME.teal}
                  strokeWidth={2.5}
                  fill="url(#rg)"
                  dot={{ fill: THEME.teal, r: 3 }}
                />
              </AreaChart>
            </ResponsiveContainer>
          )}
        </Card>

        <Card style={{ padding: "22px 24px" }}>
          <div style={{ fontSize: 15, fontWeight: 700, color: THEME.slate800, marginBottom: 4 }}>
            Session activity
          </div>
          <div style={{ fontSize: 12, color: THEME.slate400, marginBottom: 18 }}>
            This week
          </div>
          <ResponsiveContainer width="100%" height={170}>
            <BarChart data={actData} margin={{ top: 5, right: 5, bottom: 0, left: -28 }}>
              <CartesianGrid strokeDasharray="3 3" stroke={THEME.slate100} />
              <XAxis
                dataKey="day"
                tick={{ fontSize: 11, fill: THEME.slate400 }}
                axisLine={false}
                tickLine={false}
              />
              <YAxis
                tick={{ fontSize: 11, fill: THEME.slate400 }}
                axisLine={false}
                tickLine={false}
              />
              <Tooltip
                contentStyle={{
                  borderRadius: 9,
                  border: `1px solid ${THEME.slate200}`,
                  fontSize: 12,
                }}
              />
              <Bar dataKey="s" fill={THEME.teal} radius={[4, 4, 0, 0]} name="Sessions" />
            </BarChart>
          </ResponsiveContainer>
        </Card>
      </div>

      {/* Recent patients quick list */}
      <Card style={{ overflow: "hidden" }}>
        <div
          style={{
            padding: "18px 24px",
            borderBottom: `1px solid ${THEME.slate100}`,
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
          }}
        >
          <div style={{ fontSize: 15, fontWeight: 700, color: THEME.slate800 }}>
            Recent patient activity
          </div>
          <button
            onClick={() => setPage("patients")}
            style={{
              fontSize: 13,
              color: THEME.teal,
              background: "none",
              border: "none",
              cursor: "pointer",
              fontWeight: 600,
            }}
          >
            View all →
          </button>
        </div>
        {approvedPatients
          .slice(0, 4)
          .map((p, i, arr) => (
            <div
              key={p.id}
              onClick={() => {
                setSelectedPatientId(p.id);
                setPage("patients");
              }}
              style={{
                display: "grid",
                gridTemplateColumns: "2fr 2fr 1.5fr 1fr 1fr",
                padding: "13px 24px",
                borderBottom: i < arr.length - 1 ? `1px solid ${THEME.slate100}` : "none",
                alignItems: "center",
                cursor: "pointer",
                transition: "background 0.12s",
              }}
              onMouseEnter={(e) => (e.currentTarget.style.background = THEME.slate50)}
              onMouseLeave={(e) => (e.currentTarget.style.background = "transparent")}
            >
              <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                <div
                  style={{
                    width: 32,
                    height: 32,
                    borderRadius: "50%",
                    background: THEME.navy,
                    color: THEME.white,
                    fontSize: 12,
                    fontWeight: 700,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    flexShrink: 0,
                  }}
                >
                  {VisualizationService.getInitials(p.name)}
                </div>
                <div style={{ fontSize: 13, fontWeight: 600, color: THEME.slate800 }}>
                  {p.name}
                </div>
              </div>
              <div style={{ fontSize: 12, color: THEME.slate500 }}>{p.injury}</div>
              <RomBar value={p.rom} />
              <Badge status={p.status} />
              <div
                style={{
                  fontSize: 11,
                  color:
                    p.trend > 0
                      ? THEME.green
                      : p.trend < 0
                        ? THEME.red
                        : THEME.slate400,
                  fontWeight: 600,
                }}
              >
                {p.trend > 0 ? `+${p.trend}°` : p.trend < 0 ? `${p.trend}°` : "—"} this week
              </div>
            </div>
          ))}
      </Card>
    </div>
  );
}

export default DashboardPage;
