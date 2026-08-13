# Arma el JSON de las cuentas.
#
# Vive aparte del controlador porque el mismo resumen se usa en la lista y
# dentro del detalle, y porque el shape de la respuesta es justamente lo que el
# frontend consume: conviene poder testearlo sin levantar una peticion.
#
# Las claves mezclan español e ingles a proposito: `currentLevel` y `maxLevel`
# son los nombres que el frontend ya usa desde la epoca del Google Sheet, y
# renombrarlos ahora obligaria a tocar los componentes sin ganar nada.
class AccountSerializer
  def initialize(account)
    @account = account
  end

  # Lo justo para pintar la lista de cuentas. Sin el report: calcularlo por
  # cuenta agregaria una consulta agregada por fila de la lista.
  def resumen
    {
      id: account.id,
      nombre: account.nombre,
      townHall: account.town_hall,
      builderHall: account.builder_hall,
      tagCoc: account.tag_coc,
      orden: account.orden,
      sincronizable: account.sincronizable?
    }
  end

  # El detalle completo: la cuenta, su progreso agrupado por seccion y el
  # report calculado.
  def completo
    {
      account: resumen,
      secciones: secciones,
      report: account.report
    }
  end

  private

  attr_reader :account

  # Account#secciones ya devuelve las categorias en el orden del Sheet y precarga
  # los niveles del catalogo, asi que serializar aca no dispara consultas extra.
  def secciones
    account.secciones.transform_values do |items|
      items.map { |item| AccountItemSerializer.new(item).call }
    end
  end
end
