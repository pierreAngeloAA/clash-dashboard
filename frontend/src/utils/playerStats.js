// Helpers for the player stats synced from the official Clash API.

const CLAN_ROLES = {
  leader: 'Leader',
  coLeader: 'Co-leader',
  admin: 'Elder', // the API calls elders "admin"
  member: 'Member',
};

export function formatClanRole(role) {
  return CLAN_ROLES[role] ?? null;
}

const numberFormat = new Intl.NumberFormat('en-US');

// Stats are null until the account is synced for the first time.
export function formatStat(value) {
  return value == null ? '—' : numberFormat.format(value);
}

export function hasPlayerStats(account) {
  return Object.values(account?.stats ?? {}).some((value) => value != null);
}
