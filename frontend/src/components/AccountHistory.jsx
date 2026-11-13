import { useEffect, useState } from 'react';
import { fetchAccountHistory } from '../services/accountsService';
import { buildSeries } from '../utils/historyChart';
import { formatStat } from '../utils/playerStats';

const WIDTH = 300;
const HEIGHT = 64;

const METRICS = [
  { key: 'progressPct', label: 'Progress', format: (v) => `${v.toFixed(1)}%` },
  { key: 'trophies', label: 'Trophies', format: formatStat },
  { key: 'warStars', label: 'War stars', format: formatStat },
];

function Sparkline({ snapshots, metric }) {
  const series = buildSeries(snapshots, metric.key, { width: WIDTH, height: HEIGHT });
  if (series.points.length < 2) return null;

  const line = series.points.map((p) => `${p.x},${p.y}`).join(' ');
  const area = `0,${HEIGHT} ${line} ${WIDTH},${HEIGHT}`;
  const delta = series.last - series.first;
  const end = series.points[series.points.length - 1];

  return (
    <div className="px-4 py-3">
      <div className="flex items-baseline justify-between gap-2">
        <span className="text-[10px] font-semibold uppercase tracking-wider text-slate-500">
          {metric.label}
        </span>
        <span className="text-sm font-bold text-slate-900 tabular-nums">
          {metric.format(series.last)}
          {delta !== 0 && (
            <span className={`ml-1.5 text-xs font-semibold ${delta > 0 ? 'text-emerald-600' : 'text-rose-600'}`}>
              {delta > 0 ? '+' : '−'}
              {metric.format(Math.abs(delta))}
            </span>
          )}
        </span>
      </div>
      <svg
        viewBox={`-4 -4 ${WIDTH + 8} ${HEIGHT + 8}`}
        className="mt-2 w-full h-16 overflow-visible"
        role="img"
        aria-label={`${metric.label}: from ${metric.format(series.first)} to ${metric.format(series.last)}`}
      >
        <polygon points={area} className="fill-brand-500/10" />
        <polyline
          points={line}
          fill="none"
          className="stroke-brand-600"
          strokeWidth="2"
          strokeLinejoin="round"
          strokeLinecap="round"
          vectorEffect="non-scaling-stroke"
        />
        <circle cx={end.x} cy={end.y} r="3.5" className="fill-brand-600" />
      </svg>
      <div className="mt-1 flex justify-between text-[10px] text-slate-400 tabular-nums">
        <span>{series.points[0].date}</span>
        <span>{end.date}</span>
      </div>
    </div>
  );
}

/**
 * How the account evolved, from the daily snapshots taken on each sync.
 * Shows a hint until there are at least two synced days to compare.
 */
export default function AccountHistory({ accountId }) {
  const [snapshots, setSnapshots] = useState(null);

  useEffect(() => {
    let active = true;
    fetchAccountHistory(accountId)
      .then((data) => active && setSnapshots(data))
      // History is a nice-to-have: if it fails, the rest of the page still works.
      .catch(() => active && setSnapshots([]));
    return () => {
      active = false;
    };
  }, [accountId]);

  if (snapshots == null) return null;

  return (
    <section className="mt-4 bg-white rounded-xl shadow-card border border-slate-100 overflow-hidden">
      <h2 className="px-4 py-2.5 border-b border-slate-100 font-semibold text-sm text-slate-900">
        History
      </h2>
      {snapshots.length < 2 ? (
        <p className="px-4 py-3 text-sm text-slate-500">
          The history starts with the first sync and shows up once the account has been synced on two different days.
        </p>
      ) : (
        <div className="grid sm:grid-cols-3 divide-y sm:divide-y-0 sm:divide-x divide-slate-100">
          {METRICS.map((metric) => (
            <Sparkline key={metric.key} snapshots={snapshots} metric={metric} />
          ))}
        </div>
      )}
    </section>
  );
}
