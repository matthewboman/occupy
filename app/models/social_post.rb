class SocialPost < ApplicationRecord
  has_many :security_mentions, dependent: :destroy
  has_many :securities, through: :security_mentions

  validates :source, presence: true
  validates :external_id, presence: true
  validates :body, presence: true
  validates :posted_at, presence: true

  validates :external_id,
            uniqueness: {
              scope: :source
            }
end