require "rails_helper"

RSpec.describe AccountSnapshot do
  include ActiveSupport::Testing::TimeHelpers

  let(:account) { create(:account, town_hall: nil, trophies: 5000, war_stars: 1200, donations: 300) }

  describe ".record!" do
    it "stores today's progress and stats for the account" do
      allow(Account).to receive(:progreso_pct).and_return({ account.id => 87.5 })

      snapshot = described_class.record!(account)

      expect(snapshot).to have_attributes(
        taken_on: Date.current, progress_pct: 87.5, town_hall: nil,
        trophies: 5000, war_stars: 1200, donations: 300
      )
    end

    it "updates the same day's snapshot instead of adding another" do
      described_class.record!(account)
      account.update!(trophies: 5100)

      expect { described_class.record!(account) }.not_to change(described_class, :count)
      expect(described_class.last.trophies).to eq(5100)
    end

    it "adds a new snapshot on a different day" do
      described_class.record!(account)

      travel_to(1.day.from_now) do
        expect { described_class.record!(account) }.to change(described_class, :count).by(1)
      end
    end

    it "records 0% for an account without progress" do
      expect(described_class.record!(account).progress_pct).to eq(0)
    end
  end

  it "is deleted with its account" do
    described_class.record!(account)

    expect { account.destroy }.to change(described_class, :count).by(-1)
  end
end
