require "test_helper"

module SocialData
  class ExtractAllSecurityMentionsTest < ActiveSupport::TestCase
    test "extracts mentions across social posts" do
      SocialPost.create!(
        source:      "reddit",
        external_id: "batch-test-nvda",
        body:        "NVDA looks strong",
        posted_at:   Time.current
      )

      SocialPost.create!(
        source:      "reddit",
        external_id: "batch-test-gme",
        body:        "Watching GME",
        posted_at:   Time.current
      )

      ExtractAllSecurityMentions.new.call

      nvda_post = SocialPost.find_by!(
        external_id: "batch-test-nvda"
      )

      gme_post = SocialPost.find_by!(
        external_id: "batch-test-gme"
      )

      assert_equal(
        ["NVDA"],
        nvda_post.securities.pluck(:symbol)
      )

      assert_equal(
        ["GME"],
        gme_post.securities.pluck(:symbol)
      )
    end
  end
end