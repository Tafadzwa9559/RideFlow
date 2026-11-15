import { money } from "../../utils/format";
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
  BarChart,
  Bar,
} from "recharts";
import { earningsData } from "../../services/analytics.mock";

export function EarningsChart({ bars = false }: { bars?: boolean }) {
  return (
    <div
      className="chart"
      role="img"
      aria-label="Sample weekly earnings: Monday 24, Tuesday 38, Wednesday 31, Thursday 47, Friday 35, Saturday 59, Sunday 42 US dollars"
    >
      <ResponsiveContainer width="100%" height={260}>
        {bars ? (
          <BarChart data={earningsData}>
            <CartesianGrid
              strokeDasharray="3 3"
              vertical={false}
              stroke="#e5e7eb"
            />
            <XAxis dataKey="day" axisLine={false} tickLine={false} />
            <YAxis axisLine={false} tickLine={false} />
            <Tooltip formatter={(v) => money(Number(v))} />
            <Bar dataKey="gross" fill="#10b981" radius={[5, 5, 0, 0]} />
          </BarChart>
        ) : (
          <AreaChart data={earningsData}>
            <defs>
              <linearGradient id="earnings-fill" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#10b981" stopOpacity={0.22} />
                <stop offset="100%" stopColor="#10b981" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid
              strokeDasharray="3 3"
              vertical={false}
              stroke="#e5e7eb"
            />
            <XAxis dataKey="day" axisLine={false} tickLine={false} />
            <YAxis axisLine={false} tickLine={false} />
            <Tooltip formatter={(v) => money(Number(v))} />
            <Area
              type="monotone"
              dataKey="gross"
              stroke="#10b981"
              strokeWidth={3}
              fill="url(#earnings-fill)"
            />
          </AreaChart>
        )}
      </ResponsiveContainer>
    </div>
  );
}
export function KPIs({
  items,
}: {
  items: { label: string; value: string; note?: string }[];
}) {
  return (
    <div className="kpi-grid">
      {items.map((item) => (
        <section className="kpi" key={item.label}>
          <span>{item.label}</span>
          <strong>{item.value}</strong>
          <small>{item.note || "Sample data · demonstration only"}</small>
        </section>
      ))}
    </div>
  );
}
