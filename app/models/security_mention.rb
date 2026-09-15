class SecurityMention < ApplicationRecord
  belongs_to :social_post
  belongs_to :security

  has_one :security_mention_outcome, dependent: :destroy

  validates :match_type,
            inclusion: {
              in: %w[
                cashtag
                ticker
                company_name
              ]
            },
            allow_nil: true

  validates :security_id,
            uniqueness: {
              scope: :social_post_id
            }

  scope :from_cashtag, -> {
    self.where(match_type: "cashtag")
  }

  scope :from_company_name, -> {
    self.where(match_type: "company_name")
  }

  scope :from_ticker, -> {
    self.where(match_type: "ticker")
  }

end