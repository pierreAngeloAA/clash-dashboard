module Api
  module V1
    # Edicion del progreso de una cuenta: subir el nivel de un heroe, corregir
    # el tope de un canon, proteger un elemento de la sincronizacion.
    #
    # No hay create ni destroy: el inventario no se arma a mano, lo deriva
    # PoblarCuenta del catalogo y del ayuntamiento de la cuenta. Un elemento
    # creado suelto aca quedaria fuera de esa regla, y uno borrado volveria a
    # aparecer en el siguiente repoblado.
    class AccountItemsController < ApplicationController
      before_action :autenticar!

      def update
        item.update!(parametros_del_item)

        render json: { item: AccountItemSerializer.new(item).call }
      end

      private

      # Se busca dentro de la cuenta de la URL: con el id suelto se podria editar
      # el elemento de otra cuenta pasando un id ajeno.
      def item
        @item ||= Account.find(params[:account_id]).account_items.find(params[:id])
      end

      # `fuente` no se acepta del cliente: si alguien edita el nivel a mano, el
      # dato es manual por definicion. Lo pone en "api" solo la sincronizacion.
      def parametros_del_item
        permitidos = params.expect(item: [ :current_level, :max_level, :bloqueado ])

        return permitidos if permitidos[:current_level].blank?

        permitidos.merge(fuente: "manual")
      end
    end
  end
end
