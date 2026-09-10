class SecurityMention < ApplicationRecord
  belongs_to :social_post
  belongs_to :security

  validates :security_id,
            uniqueness: {
              scope: :social_post_id
            }
end