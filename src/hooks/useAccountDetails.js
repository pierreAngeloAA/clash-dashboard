import { useCallback, useEffect, useState } from 'react';
import { fetchAccountDetails } from '../services/sheetsService';

export function useAccountDetails(gid) {
  const [details, setDetails] = useState(null);
  const [loading, setLoading] = useState(Boolean(gid));
  const [error, setError] = useState(null);

  const load = useCallback(
    async ({ force = false } = {}) => {
      if (!gid) return;
      setLoading(true);
      setError(null);
      try {
        const data = await fetchAccountDetails(gid, { force });
        setDetails(data);
      } catch (err) {
        setError(err.message || 'Error al cargar el detalle.');
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

  return { details, loading, error, refetch };
}
