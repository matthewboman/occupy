class SocialPost < ApplicationRecord
  RECORD_TYPES = %w[
    submission
    comment
  ].freeze

  belongs_to :submission,
             -> { where(record_type: "submission") },
             class_name:  "SocialPost",
             primary_key: :external_id,
             foreign_key: :submission_external_id,
             optional:    true

  belongs_to :parent,
             class_name:  "SocialPost",
             primary_key: :external_id,
             foreign_key: :parent_external_id,
             optional:    true

  has_many :security_mentions, dependent: :destroy
  has_many :securities, through: :security_mentions
  has_many :comments,
           -> { where(record_type: "comment") },
           class_name:  "SocialPost",
           primary_key: :external_id,
           foreign_key: :submission_external_id
  has_many :replies,
           class_name:  "SocialPost",
           primary_key: :external_id,
           foreign_key: :parent_external_id

  validates :source,      presence: true
  validates :external_id, presence: true
  validates :body,        presence: true
  validates :posted_at,   presence: true
  validates :record_type, inclusion: { in: RECORD_TYPES }

  validates :external_id,
            uniqueness: {
              scope: :source
            }

  scope :comments, -> {
    self.where(record_type: "comment")
  }

  scope :for_subreddit, ->(subreddit) {
    where(subreddit: subreddit)
  }

  scope :submissions, -> {
    self.where(record_type: "submission")
  }

  scope :with_security_mentions, -> {
    self.joins(:security_mentions)
        .distinct
  }

  scope :without_security_mentions, -> {
    self.where.missing(:security_mentions)
  }

  def submission
    return self if record_type == "submission"
    return      if submission_external_id.blank?

    SocialPost.find_by(
      source:      source,
      external_id: submission_external_id,
      record_type: "submission"
    )
  end

  def parent
    return if parent_external_id.blank?

    SocialPost.find_by(
      source:      source,
      external_id: parent_external_id
    )
  end
end