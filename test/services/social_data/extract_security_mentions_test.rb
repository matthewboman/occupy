require "test_helper"

module SocialData
  class ExtractSecurityMentionsTest < ActiveSupport::TestCase
    test "creates security mentions for uppercase ticker symbols" do
      post = SocialPost.create!(
        source:      "reddit",
        external_id: "ticker-test-1",
        body:        "I think NVDA and GME are interesting here",
        posted_at:   Time.current
      )

      assert_difference(
        -> { SecurityMention.count },
        2
      ) do
        ExtractSecurityMentions.new(
          social_post: post
        ).call
      end

      assert_equal(
        ["GME", "NVDA"],
        post.securities.reload.order(:symbol).pluck(:symbol)
      )
    end

    test "recognizes dollar prefixed ticker symbols" do
      post = SocialPost.create!(
        source:      "reddit",
        external_id: "ticker-test-2",
        body:        "I'm watching $NVDA",
        posted_at:   Time.current
      )

      assert_difference(
        -> { SecurityMention.count },
        1
      ) do
        ExtractSecurityMentions.new(
          social_post: post
        ).call
      end

      assert_equal(
        ["NVDA"],
        post.securities.reload.pluck(:symbol)
      )
    end

    test "does not match lowercase words" do
      Security.find_or_create_by!(
        symbol: "LOVE"
      ) do |security|
        security.name          = "The Lovesac Company"
        security.security_type = "stock"
        security.exchange      = "NASDAQ"
      end

      post = SocialPost.create!(
        source:      "reddit",
        external_id: "ticker-test-3",
        body:        "I love this stock",
        posted_at:   Time.current
      )

      assert_no_difference(
        -> { SecurityMention.count }
      ) do
        ExtractSecurityMentions.new(
          social_post: post
        ).call
      end
    end

    test "does not create a mention for an unknown symbol" do
      post = SocialPost.create!(
        source:      "reddit",
        external_id: "ticker-test-4",
        body:        "ZZZZZ looks interesting",
        posted_at:   Time.current
      )

      assert_no_difference(
        -> { SecurityMention.count }
      ) do
        ExtractSecurityMentions.new(
          social_post: post
        ).call
      end
    end

    test "does not create duplicate mentions" do
      post = SocialPost.create!(
        source:      "reddit",
        external_id: "ticker-test-5",
        body:        "NVDA NVDA $NVDA",
        posted_at:   Time.current
      )

      extractor = ExtractSecurityMentions.new(
        social_post: post
      )

      extractor.call

      assert_no_difference(
        -> { SecurityMention.count }
      ) do
        extractor.call
      end

      assert_equal 1, post.security_mentions.count
    end

    test "can associate multiple securities with one post" do
      post = SocialPost.create!(
        source:      "reddit",
        external_id: "ticker-test-6",
        body:        "NVDA versus GME versus SPY",
        posted_at:   Time.current
      )

      ExtractSecurityMentions.new(
        social_post: post
      ).call

      assert_equal(
        ["GME", "NVDA", "SPY"],
        post.securities.reload.order(:symbol).pluck(:symbol)
      )
    end
  end
end