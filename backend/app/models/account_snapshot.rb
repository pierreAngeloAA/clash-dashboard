# Daily picture of an account's progress and stats, taken on every sync.
#
# The report itself is never stored (see ReportCalculator): it is recomputed
# from the inventory. Snapshots exist for the opposite reason: to remember
# values that are gone once the inventory changes.
class AccountSnapshot < ApplicationRecord
  HISTORY_WINDOW = 1.year

  belongs_to :account

  scope :recent, -> { where(taken_on: HISTORY_WINDOW.ago.to_date..).order(:taken_on) }

  # Creates today's snapshot or refreshes it when the account was already
  # synced today, so the history keeps one point per day.
  def self.record!(account)
    snapshot = find_or_initialize_by(account: account, taken_on: Date.current)
    snapshot.update!(
      progress_pct: Account.where(id: account.id).progreso_pct.fetch(account.id, 0),
      town_hall: account.town_hall,
      trophies: account.trophies,
      war_stars: account.war_stars,
      donations: account.donations
    )
    snapshot
  end

  def as_history_json
    {
      date: taken_on.iso8601,
      progressPct: progress_pct.to_f,
      townHall: town_hall,
      trophies: trophies,
      warStars: war_stars,
      donations: donations
    }
  end
end
