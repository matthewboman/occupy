require "test_helper"

class SocialPostTest < ActiveSupport::TestCase
  test "has securities through security mentions" do
    social_post = social_posts(:nvda_post)

    assert_includes social_post.securities, securities(:nvda)
  end

  test "requires a source" do
    social_post = SocialPost.new(
      external_id: "abc123",
      body: "NVDA looks bullish",
      posted_at: Time.current
    )

    assert_not social_post.valid?
    assert_includes social_post.errors[:source], "can't be blank"
  end

  test "requires an external id" do
    social_post = SocialPost.new(
      source: "reddit",
      body: "NVDA looks bullish",
      posted_at: Time.current
    )

    assert_not social_post.valid?
    assert_includes social_post.errors[:external_id], "can't be blank"
  end

  test "requires body" do
    social_post = SocialPost.new(
      source: "reddit",
      external_id: "abc123",
      posted_at: Time.current
    )

    assert_not social_post.valid?
    assert_includes social_post.errors[:body], "can't be blank"
  end

  test "requires posted at" do
    social_post = SocialPost.new(
      source: "reddit",
      external_id: "abc123",
      body: "NVDA looks bullish"
    )

    assert_not social_post.valid?
    assert_includes social_post.errors[:posted_at], "can't be blank"
  end

  test "external id must be unique within a source" do
    existing = social_posts(:nvda_post)

    duplicate = SocialPost.new(
      source: existing.source,
      external_id: existing.external_id,
      body: "Duplicate Reddit post",
      posted_at: Time.current
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end

  test "same external id can exist for different sources" do
    existing = social_posts(:nvda_post)

    social_post = SocialPost.new(
      source: "discord",
      external_id: existing.external_id,
      body: "Same id but different source",
      posted_at: Time.current
    )

    assert social_post.valid?
  end
end