module Api
  module V1
    # Lectura y administracion de las cuentas.
    #
    # Leer no exige sesion: el dashboard es publico, igual que lo era cuando
    # leia el Google Sheet compartido. Escribir si, porque es lo que reemplaza a
    # editar la planilla a mano.
    class AccountsController < ApplicationController
      before_action :autenticar!, only: %i[create update destroy]
      before_action :cargar_cuenta, only: %i[show update destroy]

      def index
        cuentas = Account.ordenadas

        render json: { accounts: cuentas.map { |cuenta| AccountSerializer.new(cuenta).resumen } }
      end

      def show
        render json: AccountSerializer.new(@cuenta).completo
      end

      # Al crear la cuenta, Account#poblar_inventario le genera los elementos que
      # su ayuntamiento habilita.
      def create
        cuenta = Account.create!(parametros_de_cuenta)

        render json: { account: AccountSerializer.new(cuenta).resumen }, status: :created
      end

      def update
        town_hall_anterior = @cuenta.town_hall
        @cuenta.update!(parametros_de_cuenta)

        # Subir de ayuntamiento habilita elementos nuevos y sube el tope de los
        # que ya tenia. Sin esto la cuenta quedaria mostrando el inventario del
        # ayuntamiento viejo hasta que alguien lo repoblara a mano.
        @cuenta.poblar_inventario if @cuenta.town_hall != town_hall_anterior

        render json: { account: AccountSerializer.new(@cuenta.reload).resumen }
      end

      # Se lleva puesto el progreso de la cuenta (`dependent: :destroy`), no solo
      # la fila.
      def destroy
        @cuenta.destroy!

        head :no_content
      end

      private

      def cargar_cuenta
        @cuenta = Account.find(params[:id])
      end

      # `gid_origen` queda afuera a proposito: lo escribe el importador del Sheet
      # para saber de que pestaña vino la cuenta, no es un dato que se edite.
      def parametros_de_cuenta
        params.expect(account: [ :nombre, :town_hall, :builder_hall, :tag_coc, :orden ])
      end
    end
  end
end
