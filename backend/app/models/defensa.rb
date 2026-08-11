# Edificaciones defensivas: canones, torres de arqueras, morteros, tesla.
#
# La API oficial no expone edificios, asi que estos datos solo pueden venir del
# Google Sheet o cargarlos el superadmin a mano.
class Defensa < AccountItem
  def self.categoria
    "NIVELES DEFENSAS"
  end
end
