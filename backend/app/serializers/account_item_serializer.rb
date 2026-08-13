# El JSON de un elemento del progreso de una cuenta.
#
# Lo usan el detalle de la cuenta y la edicion de un nivel, y en los dos casos
# tiene que ser el mismo shape: el frontend actualiza el elemento que edito con
# lo que le devuelve el PATCH, sin recargar la cuenta entera.
class AccountItemSerializer
  # `poderes` llega ya cargado desde afuera en vez de leerse de la asociacion:
  # los poderes son elementos de la misma cuenta y vienen en la misma consulta,
  # asi que agruparlos en memoria evita una consulta por heroe.
  def initialize(account_item, poderes: nil)
    @item = account_item
    @poderes = poderes
  end

  def call
    basico = {
      id: item.id,
      indice: item.indice,
      nombre: item.nombre,
      currentLevel: item.current_level,
      maxLevel: item.max_level,
      faltante: item.faltante,
      completo: item.completo?,
      fuente: item.fuente,
      bloqueado: item.bloqueado,
      niveles: item.niveles
    }

    return basico unless item.is_a?(Heroe)

    # Un heroe lleva sus poderes equipados. Siguen apareciendo tambien en la
    # seccion GUARDIANES, que es como los agrupa el Sheet.
    basico.merge(poderes: poderes.to_a.map { |poder| self.class.new(poder).call })
  end

  private

  attr_reader :item, :poderes
end
