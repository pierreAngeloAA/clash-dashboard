import { useCallback, useEffect, useState } from 'react';
import { fetchClan } from '../services/cocService';

export function useClan(tag) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    if (!tag) return;
    setLoading(true);
    setError(null);
    try {
      const result = await fetchClan(tag);
      setData(result);
    } catch (err) {
      setError(err.message || 'Error al cargar el clan.');
    } finally {
      setLoading(false);
    }
  }, [tag]);

  useEffect(() => {
    load();
  }, [load]);

  return { data, loading, error, refetch: load };
}
