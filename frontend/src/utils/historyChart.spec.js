import { describe, expect, it } from 'vitest';
import { buildSeries } from './historyChart';

const snapshots = [
  { date: '2026-11-01', trophies: 4000 },
  { date: '2026-11-02', trophies: null },
  { date: '2026-11-03', trophies: 5000 },
];

describe('buildSeries', () => {
  it('skips days without a value', () => {
    const series = buildSeries(snapshots, 'trophies', { width: 100, height: 50 });

    expect(series.points).toHaveLength(2);
  });

  it('maps the first and last day to the chart edges', () => {
    const { points } = buildSeries(snapshots, 'trophies', { width: 100, height: 50 });

    expect(points[0].x).toBe(0);
    expect(points[1].x).toBe(100);
  });

  it('puts the lowest value at the bottom and the highest at the top', () => {
    const { points } = buildSeries(snapshots, 'trophies', { width: 100, height: 50 });

    expect(points[0].y).toBe(50);
    expect(points[1].y).toBe(0);
  });

  it('reports min, max, first and last values', () => {
    const series = buildSeries(snapshots, 'trophies', { width: 100, height: 50 });

    expect(series).toMatchObject({ min: 4000, max: 5000, first: 4000, last: 5000 });
  });

  it('draws a flat line in the middle when every value is equal', () => {
    const flat = [{ date: '2026-11-01', trophies: 10 }, { date: '2026-11-02', trophies: 10 }];

    const { points } = buildSeries(flat, 'trophies', { width: 100, height: 50 });

    expect(points.map((p) => p.y)).toEqual([25, 25]);
  });

  it('returns an empty series when there is nothing to draw', () => {
    expect(buildSeries([], 'trophies', { width: 100, height: 50 }).points).toEqual([]);
  });
});
