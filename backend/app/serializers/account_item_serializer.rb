# El JSON de un elemento del progreso de una cuenta.
#
# Lo usan el detalle de la cuenta y la edicion de un nivel, y en los dos casos
# tiene que ser el mismo shape: el frontend actualiza el elemento que edito con
# lo que le devuelve el PATCH, sin recargar la cuenta entera.
class AccountItemSerializer
  def initialize(account_item)
    @item = account_item
  end

  def call
    {
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
  end

  private

  attr_reader :item
end
