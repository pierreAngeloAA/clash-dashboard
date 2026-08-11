# Usuario del panel de administracion. No hay registro publico: las cuentas de
# usuario las crea un superadmin.
class User < ApplicationRecord
  # JTIMatcher revoca tokens comparando el jti del JWT con el guardado en el
  # usuario. Al cerrar sesion se rota el jti y el token anterior deja de
  # validar, sin necesidad de mantener una tabla de tokens revocados que haya
  # que purgar.
  include Devise::JWT::RevocationStrategies::JTIMatcher

  ROLES = %w[admin superadmin].freeze

  devise :database_authenticatable,
    :validatable,
    :jwt_authenticatable,
    jwt_revocation_strategy: self

  validates :rol, presence: true, inclusion: { in: ROLES }
  validates :password, length: { minimum: 12 }, if: :password_required?

  scope :superadmins, -> { where(rol: "superadmin") }

  def superadmin?
    rol == "superadmin"
  end

  def admin?
    ROLES.include?(rol)
  end

  private

  def password_required?
    new_record? || password.present?
  end
end
