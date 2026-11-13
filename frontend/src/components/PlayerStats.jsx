import { formatClanRole, formatStat, hasPlayerStats } from '../utils/playerStats';

const STATS = [
  ['trophies', 'Trophies'],
  ['bestTrophies', 'Best'],
  ['warStars', 'War stars'],
  ['expLevel', 'XP level'],
  ['donations', 'Donated'],
  ['donationsReceived', 'Received'],
];

/**
 * Player stats and clan, as returned by the last sync with the official API.
 * Renders nothing for accounts that were never synced.
 */
export default function PlayerStats({ account }) {
  if (!hasPlayerStats(account) && !account.clan) return null;

  const { clan, stats = {} } = account;
  const role = formatClanRole(clan?.role);

  return (
    <section className="mt-4 bg-white rounded-xl shadow-card border border-slate-100 overflow-hidden">
      <div className="px-4 py-2.5 border-b border-slate-100 flex items-center gap-3">
        <h2 className="font-semibold text-sm text-slate-900">Player</h2>
        {clan && (
          <div className="ml-auto flex items-center gap-2 min-w-0">
            {clan.badgeUrl && (
              <img src={clan.badgeUrl} alt="" className="h-7 w-7 shrink-0" loading="lazy" />
            )}
            <div className="min-w-0 text-right leading-tight">
              <p className="text-sm font-semibold text-slate-900 truncate">{clan.name}</p>
              <p className="text-[11px] text-slate-500 truncate">
                {[role, clan.tag].filter(Boolean).join(' · ')}
              </p>
            </div>
          </div>
        )}
      </div>
      <dl className="grid grid-cols-3 sm:grid-cols-6 divide-x divide-slate-100">
        {STATS.map(([key, label]) => (
          <div key={key} className="px-3 py-2.5 text-center">
            <dt className="text-[10px] font-semibold uppercase tracking-wider text-slate-500">
              {label}
            </dt>
            <dd className="mt-0.5 text-base font-bold text-slate-900 tabular-nums">
              {formatStat(stats[key])}
            </dd>
          </div>
        ))}
      </dl>
    </section>
  );
}
