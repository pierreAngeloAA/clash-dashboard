import { useCallback, useEffect, useState } from 'react';
import { fetchAccountList } from '../services/sheetsService';

export function useAccountList() {
  const [accounts, setAccounts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async ({ force = false } = {}) => {
    setLoading(true);
    setError(null);
    try {
      const list = await fetchAccountList({ force });
      setAccounts(list);
    } catch (err) {
      setError(err.message || 'Error al cargar las cuentas.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const refetch = useCallback(() => load({ force: true }), [load]);

  return { accounts, loading, error, refetch };
}
