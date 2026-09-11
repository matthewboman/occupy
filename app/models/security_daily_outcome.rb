class SecurityDailyOutcome < ApplicationRecord
  belongs_to :security

  validates :date,            presence: true
  validates :market_date,     presence: true
  validates :price_at_signal, presence: true
  validates :security_id,     uniqueness: { scope: :date }
end