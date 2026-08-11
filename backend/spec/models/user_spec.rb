require "rails_helper"

RSpec.describe User do
  describe "validaciones" do
    it "acepta un usuario valido" do
      expect(build(:user)).to be_valid
    end

    it "exige email" do
      expect(build(:user, email: nil)).not_to be_valid
    end

    it "rechaza emails repetidos" do
      create(:user, email: "pierre@clash.test")

      expect(build(:user, email: "pierre@clash.test")).not_to be_valid
    end

    it "rechaza un email con formato invalido" do
      expect(build(:user, email: "no-es-un-email")).not_to be_valid
    end

    it "exige contraseñas de al menos 12 caracteres" do
      corta = build(:user, password: "corta123")

      expect(corta).not_to be_valid
      expect(corta.errors[:password]).to be_present
    end

    it "rechaza un rol desconocido" do
      expect(build(:user, rol: "invitado")).not_to be_valid
    end

    it "no exige contraseña al editar otros campos" do
      usuario = create(:user)

      expect(usuario.update(rol: "superadmin")).to be(true)
    end
  end

  describe "roles" do
    it "un admin no es superadmin" do
      expect(build(:user)).not_to be_superadmin
    end

    it "reconoce al superadmin" do
      expect(build(:user, :superadmin)).to be_superadmin
    end
  end

  describe "revocacion de tokens" do
    it "asigna un jti al crearse" do
      expect(create(:user).jti).to be_present
    end

    it "cada usuario tiene un jti distinto" do
      expect(create(:user).jti).not_to eq(create(:user).jti)
    end
  end
end
