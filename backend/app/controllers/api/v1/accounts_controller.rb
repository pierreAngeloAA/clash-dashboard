module Api
  module V1
    # Lectura y administracion de las cuentas.
    #
    # Leer no exige sesion: el dashboard es publico, igual que lo era cuando
    # leia el Google Sheet compartido. Escribir si, porque es lo que reemplaza a
    # editar la planilla a mano.
    class AccountsController < ApplicationController
      before_action :autenticar!, only: %i[create update destroy sincronizar sincronizar_todas]
      before_action :cargar_cuenta, only: %i[show update destroy sincronizar]

      # La API de Clash puede estar caida, sin token o rechazando la IP. Nada de
      # eso es culpa de quien aprieta el boton, asi que se traduce a un mensaje
      # en vez de a un 500.
      rescue_from Clash::Cliente::Error do |e|
        render json: { error: e.message }, status: :bad_gateway
      end

      rescue_from Clash::SincronizarCuenta::SinTag do |e|
        render json: { error: e.message }, status: :unprocessable_content
      end

      def index
        cuentas = Account.ordenadas
        # Una sola consulta agregada para todas las cuentas, en vez de una por
        # fila: la lista pinta una barra de progreso por cuenta.
        progresos = cuentas.progreso_pct

        render json: {
          accounts: cuentas.map do |cuenta|
            AccountSerializer.new(cuenta, progreso_pct: progresos.fetch(cuenta.id, 0.0)).resumen
          end
        }
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

      # Trae el progreso real desde la API oficial y lo aplica.
      #
      # Devuelve el resumen de lo que paso, no solo "listo": una sincronizacion
      # que actualizo tres elementos de setenta porque el catalogo esta a medio
      # mapear se ve igual de exitosa desde afuera, y no lo es.
      def sincronizar
        informe = Clash::SincronizarCuenta.new(@cuenta).call

        render json: {
          resumen: informe.resumen,
          account: AccountSerializer.new(@cuenta.reload).completo
        }
      end

      # Sincroniza de una vez todas las cuentas que tienen tag.
      #
      # Devuelve el detalle por cuenta, no un total: si una fallo porque la API
      # rechazo el token, hace falta saber cual y por que. Un numero global
      # taparia justamente el caso que importa.
      #
      # Las cuentas que fallan no frenan a las demas, y por eso la respuesta es
      # 200 aunque alguna no se haya podido sincronizar: la operacion se hizo, y
      # lo que paso con cada una esta en el cuerpo.
      def sincronizar_todas
        resultados = Clash::SincronizarTodas.new.call

        render json: {
          total: resultados.size,
          cuentas: resultados.map { |r| resumen_de(r) }
        }
      end

      # Se lleva puesto el progreso de la cuenta (`dependent: :destroy`), no solo
      # la fila.
      def destroy
        @cuenta.destroy!

        head :no_content
      end

      private

      def resumen_de(resultado)
        base = {
          id: resultado.account.id,
          nombre: resultado.account.nombre,
          ok: resultado.ok?
        }

        return base.merge(error: resultado.error) unless resultado.ok?

        base.merge(resumen: resultado.informe.resumen)
      end

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
