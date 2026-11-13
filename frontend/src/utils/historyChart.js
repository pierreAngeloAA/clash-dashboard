// Turns account snapshots into SVG coordinates for a single metric.
//
// Days are spread evenly by index rather than by date: the history has one
// point per *synced* day, and gaps between syncs would otherwise squeeze most
// of the line into a corner.
export function buildSeries(snapshots, key, { width, height }) {
  const values = snapshots
    .map((snapshot) => ({ date: snapshot.date, value: snapshot[key] }))
    .filter((entry) => entry.value != null);

  if (values.length === 0) return { points: [] };

  const numbers = values.map((entry) => entry.value);
  const min = Math.min(...numbers);
  const max = Math.max(...numbers);
  const range = max - min;
  const step = values.length > 1 ? width / (values.length - 1) : 0;

  const points = values.map((entry, index) => ({
    x: index * step,
    // SVG grows downward: the highest value goes to y = 0.
    y: range === 0 ? height / 2 : height - ((entry.value - min) / range) * height,
    date: entry.date,
    value: entry.value,
  }));

  return { points, min, max, first: numbers[0], last: numbers[numbers.length - 1] };
}
