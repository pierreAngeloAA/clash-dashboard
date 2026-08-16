import { useCallback, useEffect, useState } from 'react';
import { fetchAccountList } from '../services/accountsService';

export function useAccountList() {
  const [accounts, setAccounts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setAccounts(await fetchAccountList());
    } catch (err) {
      setError(err.message || 'Error al cargar las cuentas.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  return { accounts, loading, error, refetch: load };
}
