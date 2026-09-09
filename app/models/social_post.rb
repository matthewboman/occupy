class SocialPost < ApplicationRecord
  belongs_to :security

  validates :source,      presence: true
  validates :external_id, presence: true
  validates :body,        presence: true
  validates :posted_at,   presence: true

  validates :external_id,
            uniqueness: {
              scope: :source
            }
end