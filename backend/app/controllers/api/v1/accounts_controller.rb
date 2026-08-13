module Api
  module V1
    # Lectura del progreso de las cuentas.
    #
    # Sin autenticacion: el dashboard es publico, igual que lo era cuando leia
    # el Google Sheet compartido. Lo que exige sesion es escribir, y eso vive en
    # las acciones que agrega el paso siguiente.
    class AccountsController < ApplicationController
      def index
        cuentas = Account.ordenadas

        render json: { accounts: cuentas.map { |cuenta| AccountSerializer.new(cuenta).resumen } }
      end

      def show
        cuenta = Account.find(params[:id])

        render json: AccountSerializer.new(cuenta).completo
      end
    end
  end
end
