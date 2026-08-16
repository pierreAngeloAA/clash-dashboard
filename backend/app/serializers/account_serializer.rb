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
  # `progreso_pct` llega calculado desde afuera porque la lista lo resuelve para
  # todas las cuentas de una sola consulta (Account.progreso_pct); el detalle lo
  # toma del report, que de todos modos ya calcula.
  def initialize(account, progreso_pct: nil)
    @account = account
    @progreso_pct = progreso_pct
  end

  # Lo justo para pintar la lista de cuentas: los datos de la cuenta y la barra
  # de progreso. Sin el report entero, que trae el desglose por categoria y no
  # se muestra hasta entrar al detalle.
  def resumen
    {
      id: account.id,
      nombre: account.nombre,
      townHall: account.town_hall,
      builderHall: account.builder_hall,
      tagCoc: account.tag_coc,
      orden: account.orden,
      sincronizable: account.sincronizable?,
      progresoPct: progreso_pct
    }
  end

  # El detalle completo: la cuenta, su progreso agrupado por seccion y el
  # report calculado.
  def completo
    reporte = account.report

    {
      # El porcentaje sale del report en vez de recalcularse: es el mismo numero
      # y evita que la cabecera y el desglose puedan discrepar.
      account: resumen.merge(progresoPct: reporte[:progresoPct]),
      secciones: secciones,
      report: reporte
    }
  end

  private

  attr_reader :account, :progreso_pct

  # Account#secciones ya devuelve las categorias en el orden del Sheet y precarga
  # los niveles del catalogo, asi que serializar aca no dispara consultas extra.
  def secciones
    agrupadas = account.secciones
    # Los poderes ya vienen en esta misma consulta, dentro de la seccion
    # GUARDIANES: agruparlos aca evita ir a buscarlos de nuevo por cada heroe.
    poderes = agrupadas.values.flatten.grep(Guardian).group_by(&:heroe_id)

    agrupadas.transform_values do |items|
      items.map { |item| AccountItemSerializer.new(item, poderes: poderes[item.id]).call }
    end
  end
end
