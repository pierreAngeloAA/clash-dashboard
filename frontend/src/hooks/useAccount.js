import { useCallback, useEffect, useState } from 'react';
import { fetchAccount } from '../services/accountsService';

/**
 * Todo el detalle de una cuenta: la cuenta, su progreso por seccion y el
 * report agregado.
 *
 * Reemplaza a useAccountReport y useAccountDetails, que eran dos hooks porque
 * el Sheet exponia el REPORT y el desglose en dos lecturas distintas. El
 * backend los arma de la misma consulta, asi que pedirlos por separado serian
 * dos viajes para lo mismo.
 */
export function useAccount(id) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(Boolean(id));
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    if (!id) return;
    setLoading(true);
    setError(null);
    try {
      setData(await fetchAccount(id));
    } catch (err) {
      setError(err.message || 'Error al cargar la cuenta.');
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    load();
  }, [load]);

  return {
    account: data?.account ?? null,
    secciones: data?.secciones ?? null,
    report: data?.report ?? null,
    loading,
    error,
    refetch: load,
  };
}
