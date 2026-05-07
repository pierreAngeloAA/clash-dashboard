import Loader from './Loader';
import ErrorMessage from './ErrorMessage';
import { useClan } from '../hooks/useClan';

const fmt = (n) => (typeof n === 'number' ? n.toLocaleString('es-ES') : '—');

const roleLabel = {
  leader: 'Líder',
  coLeader: 'Co-líder',
  admin: 'Veterano',
  member: 'Miembro',
};

const typeLabel = {
  open: 'Abierto',
  inviteOnly: 'Sólo invitación',
  closed: 'Cerrado',
};

const warFreqLabel = {
  always: 'Siempre',
  moreThanOncePerWeek: 'Más de 1 por semana',
  oncePerWeek: '1 por semana',
  lessThanOncePerWeek: 'Menos de 1 por semana',
  never: 'Nunca',
  unknown: '—',
};

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

export default function ClanSearchPanel({ tag, onSelectPlayer }) {
  const { data, loading, error, refetch } = useClan(tag);

  if (!tag) return null;

  const clan = data?.clan;
  const players = data?.players || [];
  const playerByTag = new Map(
    players.filter((p) => p && !p.__error).map((p) => [p.tag, p])
  );

  return (
    <section>
      {loading && !data && <Loader />}
      {error && <ErrorMessage message={error} onRetry={refetch} />}

      {clan && (
        <div className="space-y-5">
          {/* Header */}
          <section className="bg-gradient-to-br from-brand-600 to-brand-800 text-white rounded-2xl p-6 shadow-card">
            <div className="flex flex-col sm:flex-row items-start gap-5">
              {clan.badgeUrls?.medium && (
                <img
                  src={clan.badgeUrls.medium}
                  alt={clan.name}
                  className="h-24 w-24 rounded-2xl bg-white/15 p-2"
                />
              )}
              <div className="flex-1 min-w-0">
                <h3 className="text-2xl font-bold truncate">
                  {clan.name}
                  <span className="ml-2 text-base text-brand-100 font-normal">
                    {clan.tag}
                  </span>
                </h3>
                <p className="text-brand-100 text-sm mt-1">
                  Nivel {clan.clanLevel} · {clan.members} miembros ·{' '}
                  {typeLabel[clan.type] || clan.type || '—'}
                  {clan.location?.name ? ` · ${clan.location.name}` : ''}
                </p>
                {clan.description && (
                  <p className="mt-2 text-sm text-brand-50 max-w-2xl whitespace-pre-line">
                    {clan.description}
                  </p>
                )}
              </div>
            </div>

            {/* league badges + labels */}
            <div className="mt-4 flex flex-wrap items-center gap-3">
              {clan.warLeague?.name && (
                <div className="flex items-center gap-2 bg-white/15 rounded-full pl-1 pr-3 py-1">
                  {clan.warLeague.iconUrls?.small && (
                    <img
                      src={clan.warLeague.iconUrls.small}
                      alt=""
                      className="h-6 w-6"
                    />
                  )}
                  <span className="text-xs">War: {clan.warLeague.name}</span>
                </div>
              )}
              {clan.capitalLeague?.name && (
                <div className="flex items-center gap-2 bg-white/15 rounded-full pl-1 pr-3 py-1">
                  {clan.capitalLeague.iconUrls?.small && (
                    <img
                      src={clan.capitalLeague.iconUrls.small}
                      alt=""
                      className="h-6 w-6"
                    />
                  )}
                  <span className="text-xs">
                    Capital: {clan.capitalLeague.name}
                  </span>
                </div>
              )}
              {clan.labels?.map((l) => (
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
          </section>

          {/* Stats grid */}
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
            <Stat label="Puntos clan" value={fmt(clan.clanPoints)} />
            <Stat
              label="Puntos constructor"
              value={fmt(clan.clanBuilderBasePoints)}
            />
            <Stat label="Puntos capital" value={fmt(clan.clanCapitalPoints)} />
            <Stat
              label="Trofeos requeridos"
              value={fmt(clan.requiredTrophies)}
            />
            <Stat
              label="Wars"
              value={`${fmt(clan.warWins)}-${fmt(clan.warTies ?? 0)}-${fmt(clan.warLosses ?? 0)}`}
              sub={`Racha ${fmt(clan.warWinStreak)}`}
            />
            <Stat
              label="Frecuencia de guerra"
              value={warFreqLabel[clan.warFrequency] || '—'}
            />
            <Stat
              label="Registro de guerra"
              value={clan.isWarLogPublic ? 'Público' : 'Privado'}
            />
            {clan.chatLanguage?.name && (
              <Stat label="Idioma" value={clan.chatLanguage.name} />
            )}
          </div>

          {/* Members */}
          <div>
            <h4 className="text-base font-semibold text-slate-900 mb-3">
              Miembros ({clan.memberList?.length || 0})
            </h4>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
              {(clan.memberList || []).map((m) => {
                const detail = playerByTag.get(m.tag);
                const errored = players.find(
                  (p) => p?.__error && p.tag === m.tag
                );
                return (
                  <button
                    key={m.tag}
                    type="button"
                    onClick={() => onSelectPlayer?.(m.tag)}
                    className="text-left bg-white rounded-2xl shadow-card border border-slate-100 p-4 hover:border-brand-300 hover:shadow-md transition flex gap-3"
                  >
                    {m.league?.iconUrls?.tiny ? (
                      <img
                        src={m.league.iconUrls.tiny}
                        alt={m.league?.name || ''}
                        className="h-12 w-12 rounded-lg shrink-0"
                      />
                    ) : (
                      <div className="h-12 w-12 rounded-lg bg-slate-100 grid place-items-center text-sm font-bold text-slate-500 shrink-0">
                        {detail?.townHallLevel ?? m.townHallLevel ?? '?'}
                      </div>
                    )}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between gap-2">
                        <p className="font-semibold text-slate-900 truncate">
                          {m.name}
                        </p>
                        <span className="text-xs text-brand-700 font-bold">
                          TH{detail?.townHallLevel ?? m.townHallLevel ?? '?'}
                        </span>
                      </div>
                      <p className="text-xs text-slate-500 truncate">{m.tag}</p>
                      <div className="mt-2 grid grid-cols-3 gap-2 text-xs text-slate-600">
                        <div>
                          <p className="text-slate-400">Rol</p>
                          <p className="font-medium">
                            {roleLabel[m.role] || m.role}
                          </p>
                        </div>
                        <div>
                          <p className="text-slate-400">Copas</p>
                          <p className="font-medium tabular-nums">
                            {fmt(m.trophies)}
                          </p>
                        </div>
                        <div>
                          <p className="text-slate-400">Donadas</p>
                          <p className="font-medium tabular-nums">
                            {fmt(m.donations)}
                          </p>
                        </div>
                      </div>
                      {errored && (
                        <p className="mt-2 text-xs text-red-500">
                          Error al cargar detalle
                        </p>
                      )}
                    </div>
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      )}
    </section>
  );
}
