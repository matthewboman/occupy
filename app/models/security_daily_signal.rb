class SecurityDailySignal < ApplicationRecord
  belongs_to :security

  validates :date, presence: true
  validates :security_id, uniqueness: { scope: :date }
end