import { describe, expect, it } from 'vitest';
import { formatClanRole, formatStat, hasPlayerStats } from './playerStats';

describe('formatClanRole', () => {
  it('maps the API role names to readable labels', () => {
    expect(formatClanRole('leader')).toBe('Leader');
    expect(formatClanRole('coLeader')).toBe('Co-leader');
    expect(formatClanRole('admin')).toBe('Elder');
    expect(formatClanRole('member')).toBe('Member');
  });

  it('returns null for a missing or unknown role', () => {
    expect(formatClanRole(null)).toBeNull();
    expect(formatClanRole('somethingNew')).toBeNull();
  });
});

describe('formatStat', () => {
  it('groups thousands', () => {
    expect(formatStat(5123)).toBe('5,123');
  });

  it('shows a dash for values never synced', () => {
    expect(formatStat(null)).toBe('—');
    expect(formatStat(undefined)).toBe('—');
  });
});

describe('hasPlayerStats', () => {
  it('is false before the first sync', () => {
    expect(hasPlayerStats({ stats: { trophies: null, warStars: null } })).toBe(false);
    expect(hasPlayerStats({})).toBe(false);
  });

  it('is true once any stat is present', () => {
    expect(hasPlayerStats({ stats: { trophies: 0, warStars: null } })).toBe(true);
  });
});
