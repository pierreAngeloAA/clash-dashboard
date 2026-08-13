import { useCallback, useEffect, useState } from 'react';
import { fetchAccountReport } from '../services/sheetsService';

export function useAccountReport(gid) {
  const [report, setReport] = useState(null);
  const [loading, setLoading] = useState(Boolean(gid));
  const [error, setError] = useState(null);

  const load = useCallback(
    async ({ force = false } = {}) => {
      if (!gid) return;
      setLoading(true);
      setError(null);
      try {
        const data = await fetchAccountReport(gid, { force });
        setReport(data);
      } catch (err) {
        setError(err.message || 'Error al cargar el reporte.');
      } finally {
        setLoading(false);
      }
    },
    [gid]
  );

  useEffect(() => {
    load();
  }, [load]);

  const refetch = useCallback(() => load({ force: true }), [load]);

  return { report, loading, error, refetch };
}
