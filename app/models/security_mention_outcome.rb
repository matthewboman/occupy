class SecurityMentionOutcome < ApplicationRecord
  belongs_to :security_mention

  validates :market_date, presence: true
  validates :price_at_mention, presence: true
  validates :security_mention_id, uniqueness: true
end