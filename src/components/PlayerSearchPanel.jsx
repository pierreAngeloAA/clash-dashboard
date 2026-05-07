import { useMemo } from 'react';
import Loader from './Loader';
import ErrorMessage from './ErrorMessage';
import { usePlayer } from '../hooks/usePlayer';

const fmt = (n) => (typeof n === 'number' ? n.toLocaleString('es-ES') : '—');

const HOME_VILLAGE = 'home';

const groupBy = (items, getKey) => {
  const out = new Map();
  (items || []).forEach((it) => {
    const k = getKey(it);
    if (!out.has(k)) out.set(k, []);
    out.get(k).push(it);
  });
  return out;
};

const completionPct = (items) => {
  const arr = items.filter((i) => i.maxLevel > 0);
  if (!arr.length) return null;
  const sum = arr.reduce((acc, i) => acc + i.level / i.maxLevel, 0);
  return Math.round((sum / arr.length) * 100);
};

function ProgressBar({ value, max }) {
  const pct = max ? Math.min(100, Math.round((value / max) * 100)) : 0;
  const tone =
    pct === 100
      ? 'bg-emerald-500'
      : pct >= 75
        ? 'bg-brand-500'
        : pct >= 40
          ? 'bg-amber-500'
          : 'bg-rose-500';
  return (
    <div className="h-1.5 w-full bg-slate-100 rounded-full overflow-hidden">
      <div className={`h-full ${tone}`} style={{ width: `${pct}%` }} />
    </div>
  );
}

function ItemRow({ item }) {
  return (
    <div className="flex items-center gap-3 py-1.5">
      <div className="flex-1 min-w-0">
        <p className="text-sm text-slate-800 truncate">{item.name}</p>
        <ProgressBar value={item.level} max={item.maxLevel} />
      </div>
      <p className="text-xs font-mono text-slate-500 w-16 text-right">
        {item.level}/{item.maxLevel}
      </p>
    </div>
  );
}

function Section({ title, items, subtitle }) {
  if (!items?.length) return null;
  const pct = completionPct(items);
  return (
    <section className="bg-white rounded-2xl shadow-card border border-slate-100 p-5">
      <div className="flex items-center justify-between mb-3">
        <div>
          <h3 className="font-semibold text-slate-900">{title}</h3>
          {subtitle && <p className="text-xs text-slate-500">{subtitle}</p>}
        </div>
        {pct !== null && (
          <span className="text-xs font-mono px-2 py-1 rounded-full bg-brand-50 text-brand-700">
            {pct}% maxed
          </span>
        )}
      </div>
      <div className="divide-y divide-slate-100">
        {items.map((it) => (
          <ItemRow key={`${it.name}-${it.village || ''}`} item={it} />
        ))}
      </div>
    </section>
  );
}

function Stat({ label, value, sub }) {
  return (
    <div className="bg-white rounded-xl shadow-card border border-slate-100 p-3">
      <p className="text-[10px] uppercase tracking-wider text-slate-500 font-semibold">
        {label}
      </p>
      <p className="text-lg font-bold text-slate-900 tabular-nums mt-0.5 truncate">
        {value}
      </p>
      {sub && <p className="text-xs text-slate-500 mt-0.5 truncate">{sub}</p>}
    </div>
  );
}

export default function PlayerSearchPanel({ tag }) {
  const { data, loading, error, refetch } = usePlayer(tag);

  const sections = useMemo(() => {
    if (!data) return null;
    const homeOnly = (arr) =>
      (arr || []).filter((i) => (i.village || HOME_VILLAGE) === HOME_VILLAGE);
    const allTroops = homeOnly(data.troops);
    const troopsByType = groupBy(allTroops, (t) => {
      const name = t.name || '';
      if (/Super /i.test(name)) return 'super';
      if (
        /Wall Wrecker|Battle Blimp|Stone Slammer|Siege Barracks|Log Launcher|Flame Flinger|Battle Drill|Troop Launcher/i.test(
          name
        )
      ) {
        return 'siege';
      }
      return 'normal';
    });
    return {
      heroes: homeOnly(data.heroes),
      heroEquipment: homeOnly(data.heroEquipment),
      heroPets: homeOnly(data.heroPets),
      troops: troopsByType.get('normal') || [],
      superTroops: troopsByType.get('super') || [],
      siegeMachines: troopsByType.get('siege') || [],
      spells: homeOnly(data.spells),
    };
  }, [data]);

  if (!tag) return null;

  return (
    <section>
      {loading && !data && <Loader />}
      {error && <ErrorMessage message={error} onRetry={refetch} />}

      {data && sections && (
        <div className="space-y-5">
          {/* Header */}
          <section className="bg-gradient-to-br from-brand-600 to-brand-800 text-white rounded-2xl p-6 shadow-card">
            <div className="flex flex-col sm:flex-row items-start gap-5">
              {data.league?.iconUrls?.medium ? (
                <img
                  src={data.league.iconUrls.medium}
                  alt={data.league.name}
                  className="h-24 w-24 rounded-2xl bg-white/15 p-2"
                />
              ) : (
                <div className="h-24 w-24 rounded-2xl bg-white/15 backdrop-blur grid place-items-center text-4xl font-bold">
                  {data.townHallLevel ?? '?'}
                </div>
              )}
              <div className="flex-1 min-w-0">
                <h3 className="text-2xl font-bold truncate">{data.name}</h3>
                <p className="text-brand-100 text-sm mt-0.5">
                  {data.tag} · TH {data.townHallLevel ?? '?'}
                  {data.townHallWeaponLevel
                    ? ` (arma ${data.townHallWeaponLevel})`
                    : ''}{' '}
                  · XP {data.expLevel}
                </p>
                {data.league?.name && (
                  <p className="text-brand-50 text-sm mt-1">{data.league.name}</p>
                )}
                {data.clan && (
                  <div className="mt-3 flex items-center gap-2">
                    {data.clan.badgeUrls?.small && (
                      <img
                        src={data.clan.badgeUrls.small}
                        alt=""
                        className="h-7 w-7 rounded bg-white/10 p-0.5"
                      />
                    )}
                    <p className="text-sm">
                      <span className="font-semibold">{data.clan.name}</span>
                      <span className="text-brand-100">
                        {' '}
                        · {data.role || 'miembro'} · nivel {data.clan.clanLevel}
                      </span>
                    </p>
                  </div>
                )}
                {data.warPreference && (
                  <p className="text-brand-100 text-xs mt-2">
                    Preferencia de guerra: <strong>{data.warPreference}</strong>
                  </p>
                )}
              </div>
            </div>

            {data.labels?.length > 0 && (
              <div className="mt-4 flex flex-wrap gap-2">
                {data.labels.map((l) => (
                  <div
                    key={l.id}
                    className="flex items-center gap-1.5 bg-white/15 rounded-full px-3 py-1 text-xs"
                  >
                    {l.iconUrls?.small && (
                      <img src={l.iconUrls.small} alt="" className="h-4 w-4" />
                    )}
                    {l.name}
                  </div>
                ))}
              </div>
            )}
          </section>

          {/* Stats grid */}
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
            <Stat
              label="Copas"
              value={fmt(data.trophies)}
              sub={`Best ${fmt(data.bestTrophies)}`}
            />
            <Stat
              label="Aldea constructor"
              value={fmt(data.builderBaseTrophies)}
              sub={`BH ${data.builderHallLevel ?? '—'} · Best ${fmt(
                data.bestBuilderBaseTrophies
              )}`}
            />
            <Stat label="Wins ataque" value={fmt(data.attackWins)} />
            <Stat label="Wins defensa" value={fmt(data.defenseWins)} />
            <Stat label="War stars" value={fmt(data.warStars)} />
            <Stat
              label="Donadas"
              value={fmt(data.donations)}
              sub={`Recibidas ${fmt(data.donationsReceived)}`}
            />
            <Stat
              label="Capital aporte"
              value={fmt(data.clanCapitalContributions)}
            />
            {data.builderBaseLeague?.name && (
              <Stat
                label="Liga constructor"
                value={data.builderBaseLeague.name}
              />
            )}
            {data.legendStatistics?.bestSeason && (
              <Stat
                label="Mejor temporada legend"
                value={fmt(data.legendStatistics.bestSeason.trophies)}
                sub={`#${data.legendStatistics.bestSeason.rank ?? '?'} (${data.legendStatistics.bestSeason.id})`}
              />
            )}
            {data.legendStatistics?.currentSeason && (
              <Stat
                label="Legend actual"
                value={fmt(data.legendStatistics.currentSeason.trophies)}
              />
            )}
            {Array.isArray(data.achievements) &&
              data.achievements.length > 0 && (
                <Stat
                  label="Logros 3★"
                  value={`${data.achievements.filter((a) => a.stars === 3).length} / ${data.achievements.length}`}
                />
              )}
          </div>

          {/* Sections */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <Section title="Héroes" items={sections.heroes} />
            <Section title="Mascotas" items={sections.heroPets} />
            <Section
              title="Equipamiento de héroes"
              items={sections.heroEquipment}
            />
            <Section title="Hechizos" items={sections.spells} />
            <Section title="Tropas" items={sections.troops} />
            <Section title="Super tropas" items={sections.superTroops} />
            <Section title="Máquinas de asedio" items={sections.siegeMachines} />
          </div>

          <p className="text-xs text-slate-400 text-center">
            Defensas, trampas y muros no están expuestos por la API oficial.
          </p>
        </div>
      )}
    </section>
  );
}
