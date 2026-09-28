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
import { tooltipProps, axisTick, pagePadding } from "../components/chartTheme";
import useIsMobile from "../../useIsMobile";

function greetingFor(user) {
  const hour = new Date().getHours();
  const greeting = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening";
  // "Dr. Tehreem Zaheer" -> "Dr. Zaheer"
  const parts = (user?.name ?? "").trim().split(/\s+/).filter(Boolean);
  const name = parts.length > 1 && /^dr\.?$/i.test(parts[0]) ? `Dr. ${parts[parts.length - 1]}` : parts[0];
  return name ? `${greeting}, ${name}` : greeting;
}

function DashboardPage({ patients = [], setPage, setSelectedPatientId, user }) {
  const isMobile = useIsMobile();
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
    <div style={{ padding: pagePadding(isMobile) }}>
      <SectionHead
        title="Overview"
        sub={`${new Date().toLocaleDateString("en-PK", {
          weekday: "long",
          day: "numeric",
          month: "long",
          year: "numeric",
        })} · ${greetingFor(user)}`}
      />

      <div
        style={{
          display: "grid",
          gridTemplateColumns: isMobile ? "repeat(2, minmax(0, 1fr))" : "repeat(auto-fit, minmax(200px, 1fr))",
          gap: isMobile ? 12 : 16,
          marginBottom: isMobile ? 16 : 24,
        }}
      >
        {stats.map((s) => (
          <Card
            key={s.label}
            style={{
              padding: isMobile ? "16px" : "20px 22px",
              display: "flex",
              flexDirection: isMobile ? "column" : "row",
              gap: isMobile ? 10 : 14,
              alignItems: "flex-start",
              minWidth: 0,
            }}
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

      <div
        style={{
          display: "grid",
          gridTemplateColumns: isMobile ? "minmax(0, 1fr)" : "minmax(0, 1.5fr) minmax(0, 1fr)",
          gap: isMobile ? 16 : 20,
          marginBottom: isMobile ? 16 : 24,
        }}
      >
        <Card style={{ padding: isMobile ? "18px 16px" : "22px 24px", minWidth: 0 }}>
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
                <CartesianGrid strokeDasharray="3 3" stroke={THEME.slate200} />
                <XAxis dataKey="week" tick={axisTick()} axisLine={false} tickLine={false} />
                <YAxis tick={axisTick()} axisLine={false} tickLine={false} domain={[0, "auto"]} />
                <Tooltip {...tooltipProps()} formatter={(v) => [`${v}%`, "Avg ROM"]} />
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

        <Card style={{ padding: isMobile ? "18px 16px" : "22px 24px", minWidth: 0 }}>
          <div style={{ fontSize: 15, fontWeight: 700, color: THEME.slate800, marginBottom: 4 }}>
            Session activity
          </div>
          <div style={{ fontSize: 12, color: THEME.slate400, marginBottom: 18 }}>
            This week
          </div>
          <ResponsiveContainer width="100%" height={170}>
            <BarChart data={actData} margin={{ top: 5, right: 5, bottom: 0, left: -28 }}>
              <CartesianGrid strokeDasharray="3 3" stroke={THEME.slate200} />
              <XAxis dataKey="day" tick={axisTick()} axisLine={false} tickLine={false} />
              <YAxis tick={axisTick()} axisLine={false} tickLine={false} allowDecimals={false} />
              <Tooltip {...tooltipProps()} />
              <Bar dataKey="s" fill={THEME.teal} radius={[4, 4, 0, 0]} name="Sessions" />
            </BarChart>
          </ResponsiveContainer>
        </Card>
      </div>

      {/* Recent patients quick list */}
      <Card style={{ overflow: "hidden" }}>
        <div
          style={{
            padding: isMobile ? "16px" : "18px 24px",
            borderBottom: `1px solid ${THEME.slate200}`,
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
                gridTemplateColumns: isMobile
                  ? "minmax(0, 1fr) auto"
                  : "minmax(0, 2fr) minmax(0, 2fr) minmax(0, 1.5fr) minmax(0, 1fr) minmax(0, 1fr)",
                gap: isMobile ? "8px 12px" : 12,
                padding: isMobile ? "12px 16px" : "13px 24px",
                borderBottom: i < arr.length - 1 ? `1px solid ${THEME.slate200}` : "none",
                alignItems: "center",
                cursor: "pointer",
                transition: "background 0.12s",
              }}
              onMouseEnter={(e) => (e.currentTarget.style.background = THEME.slate50)}
              onMouseLeave={(e) => (e.currentTarget.style.background = "transparent")}
            >
              <div style={{ display: "flex", alignItems: "center", gap: 10, minWidth: 0 }}>
                <div
                  style={{
                    width: 32,
                    height: 32,
                    borderRadius: "50%",
                    background: THEME.teal,
                    color: THEME.onFill,
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
                <div style={{ minWidth: 0 }}>
                  <div
                    style={{
                      fontSize: 13,
                      fontWeight: 600,
                      color: THEME.slate800,
                      whiteSpace: "nowrap",
                      overflow: "hidden",
                      textOverflow: "ellipsis",
                    }}
                  >
                    {p.name}
                  </div>
                  {isMobile && <div style={{ fontSize: 12, color: THEME.slate500 }}>{p.injury}</div>}
                </div>
              </div>
              {!isMobile && <div style={{ fontSize: 12, color: THEME.slate500 }}>{p.injury}</div>}
              {isMobile ? (
                <Badge status={p.status} />
              ) : (
                <>
                  <RomBar value={p.rom} />
                  <Badge status={p.status} />
                </>
              )}
              {isMobile && (
                <div style={{ gridColumn: "1 / -1" }}>
                  <RomBar value={p.rom} />
                </div>
              )}
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
                  ...(isMobile && { gridColumn: "1 / -1", marginTop: -4 }),
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
