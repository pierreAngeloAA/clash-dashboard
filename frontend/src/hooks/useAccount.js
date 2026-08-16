import { useCallback, useEffect, useState } from 'react';
import { fetchAccount, updateAccountItem } from '../services/accountsService';

/**
 * Reemplaza el elemento editado alli donde aparezca.
 *
 * Un poder de heroe aparece dos veces: suelto en la seccion GUARDIANES, que es
 * como los agrupa el Sheet, y colgado de su heroe. Reemplazar solo en un lado
 * dejaria las dos vistas mostrando niveles distintos del mismo elemento.
 */
function reemplazar(secciones, actualizado) {
  const nuevo = (item) => {
    if (item.id === actualizado.id) return { ...item, ...actualizado };
    if (!item.poderes) return item;

    return { ...item, poderes: item.poderes.map(nuevo) };
  };

  return Object.fromEntries(
    Object.entries(secciones).map(([seccion, items]) => [seccion, items.map(nuevo)])
  );
}

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

  // `silencioso` recarga sin encender el estado de carga: se usa despues de
  // editar, donde la pantalla ya muestra datos y encender el loader la haria
  // parpadear por una peticion que el usuario no pidio.
  const load = useCallback(
    async ({ silencioso = false } = {}) => {
      if (!id) return;
      if (!silencioso) setLoading(true);
      setError(null);
      try {
        setData(await fetchAccount(id));
      } catch (err) {
        setError(err.message || 'Error al cargar la cuenta.');
      } finally {
        if (!silencioso) setLoading(false);
      }
    },
    [id]
  );

  useEffect(() => {
    load();
  }, [load]);

  /**
   * Edita un elemento y devuelve el que responde el backend.
   *
   * El elemento se reemplaza al instante con lo que vuelve del PATCH, sin
   * recargar la cuenta entera. Pero el report **no** esta guardado: el backend
   * lo recalcula a demanda desde el progreso, asi que cambiar un nivel lo deja
   * viejo y hay que volver a pedirlo. Esa recarga va en silencio y por detras.
   */
  const editarItem = useCallback(
    async (itemId, cambios) => {
      const actualizado = await updateAccountItem(id, itemId, cambios);

      setData((previo) =>
        previo
          ? { ...previo, secciones: reemplazar(previo.secciones, actualizado) }
          : previo
      );

      load({ silencioso: true });

      return actualizado;
    },
    [id, load]
  );

  return {
    account: data?.account ?? null,
    secciones: data?.secciones ?? null,
    report: data?.report ?? null,
    loading,
    error,
    refetch: load,
    editarItem,
  };
}
