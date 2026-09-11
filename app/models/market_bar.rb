class MarketBar < ApplicationRecord
  belongs_to :security

  validates :recorded_at, presence: true
  validates :recorded_at, uniqueness: { scope: :security_id }

  scope :suspicious, -> {
    self.where(
      suspicious: true
    )
  }

  scope :reviewed_clean, -> {
    self.where(
      suspicious: false
    )
  }
end
