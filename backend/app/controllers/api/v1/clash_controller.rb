module Api
  module V1
    # Puerta de entrada a la API oficial de Clash of Clans.
    #
    # Es lo que antes hacia el proxy Express de coc-proxy/: el token esta atado a
    # una IP y no puede viajar al navegador, asi que el frontend consulta aca.
    #
    # Sin sesion, igual que el resto de la lectura: son datos publicos del juego.
    class ClashController < ApplicationController
      rescue_from Clash::Cliente::Error, with: :error_de_clash

      def clan
        render json: cliente.clan_con_jugadores(params[:tag])
      end

      def jugador
        render json: cliente.jugador(params[:tag])
      end

      def guerra
        render json: cliente.guerra_actual(params[:tag])
      end

      # Permite comprobar desde afuera si el backend tiene token, que es el
      # motivo mas comun de que la seccion de clan no responda.
      def health
        render json: { ok: cliente.configurado?, token: cliente.configurado? }
      end

      private

      def cliente
        @cliente ||= Clash::Cliente.new
      end

      def error_de_clash(excepcion)
        render json: { error: excepcion.message, body: excepcion.cuerpo },
          status: excepcion.status
      end
    end
  end
end
