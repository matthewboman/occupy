class SecurityMention < ApplicationRecord
  belongs_to :social_post
  belongs_to :security

  has_one :security_mention_outcome, dependent: :destroy

  validates :security_id,
            uniqueness: {
              scope: :social_post_id
            }
end