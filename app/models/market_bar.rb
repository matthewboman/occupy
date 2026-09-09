class MarketBar < ApplicationRecord
  belongs_to :security

  validates :recorded_at, presence: true
  validates :recorded_at, uniqueness: { scope: :security_id }
end
