module Clash
  # Sincroniza de una vez todas las cuentas que tienen tag.
  #
  # Existe aparte de SincronizarCuenta porque el problema es otro: ahi importa
  # que se aplica y que no dentro de una cuenta; aca, que el fallo de una no se
  # lleve puestas a las demas. Cada cuenta es una llamada a una API ajena, que
  # puede estar caida, rechazar el token o tardar, y trece cuentas son trece
  # oportunidades de que eso pase.
  class SincronizarTodas
    # Lo que le paso a una cuenta: o un informe, o el motivo por el que no se
    # pudo. Nunca las dos cosas.
    Resultado = Struct.new(:account, :informe, :error, keyword_init: true) do
      def ok? = error.nil?
    end

    def initialize(cliente: Cliente.new)
      @cliente = cliente
    end

    def call
      Account.sincronizables.ordenadas.map { |cuenta| sincronizar(cuenta) }
    end

    private

    attr_reader :cliente

    def sincronizar(cuenta)
      informe = SincronizarCuenta.new(cuenta, cliente: cliente).call

      Resultado.new(account: cuenta, informe: informe)
    rescue Cliente::Error, SincronizarCuenta::SinTag => e
      # Solo los errores previstos: que la API rechace el token o que la cuenta
      # se quede sin tag entre que se listo y se sincronizo. Un fallo de
      # programacion tiene que seguir subiendo, no esconderse en un informe.
      Resultado.new(account: cuenta, error: e.message)
    end
  end
end
