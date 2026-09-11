require "test_helper"

module SocialData
  class BuildSecurityDailySignalsTest < ActiveSupport::TestCase
    test "builds one daily signal per security and date" do
      security = securities(:nvda)

      SecurityDailySignal.delete_all

      post_one = SocialPost.create!(
        source: "reddit",
        subreddit: "wallstreetbets",
        external_id: "signal-post-1",
        record_type: "submission",
        author: "trader_one",
        body: "NVDA",
        posted_at: Time.zone.parse("2023-12-01 10:00:00"),
        score: 10
      )

      post_two = SocialPost.create!(
        source: "reddit",
        subreddit: "wallstreetbets",
        external_id: "signal-post-2",
        record_type: "comment",
        author: "trader_two",
        body: "NVDA",
        posted_at: Time.zone.parse("2023-12-01 11:00:00"),
        score: 20
      )

      SecurityMention.create!(
        security: security,
        social_post: post_one
      )

      SecurityMention.create!(
        security: security,
        social_post: post_two
      )

      BuildSecurityDailySignals.new.call

      signal = SecurityDailySignal.find_by!(
        security: security,
        date: Date.new(2023, 12, 1)
      )

      assert_equal 2, signal.mention_count
      assert_equal 1, signal.submission_count
      assert_equal 1, signal.comment_count
      assert_equal 2, signal.unique_author_count
      assert_equal 30, signal.total_score
      assert_equal 15.0, signal.average_score.to_f
    end

    test "updates an existing daily signal instead of duplicating it" do
      security = securities(:nvda)

      SecurityDailySignal.delete_all

      BuildSecurityDailySignals.new.call
      first_count = SecurityDailySignal.count

      BuildSecurityDailySignals.new.call

      assert_equal first_count, SecurityDailySignal.count
    end
  end
end