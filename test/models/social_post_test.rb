require "test_helper"

class SocialPostTest < ActiveSupport::TestCase
  test "has securities through security mentions" do
    social_post = social_posts(:nvda_post)

    assert_includes social_post.securities, securities(:nvda)
  end

  test "requires a source" do
    social_post = SocialPost.new(
      external_id: "abc123",
      record_type: "submission",
      body:        "NVDA looks bullish",
      posted_at:   Time.current
    )

    assert_not social_post.valid?
    assert_includes social_post.errors[:source], "can't be blank"
  end

  test "requires an external id" do
    social_post = SocialPost.new(
      source:      "reddit",
      record_type: "submission",
      body:        "NVDA looks bullish",
      posted_at:   Time.current
    )

    assert_not social_post.valid?
    assert_includes social_post.errors[:external_id], "can't be blank"
  end

  test "requires body" do
    social_post = SocialPost.new(
      source:      "reddit",
      external_id: "abc123",
      record_type: "submission",
      posted_at:   Time.current
    )

    assert_not social_post.valid?
    assert_includes social_post.errors[:body], "can't be blank"
  end

  test "requires posted at" do
    social_post = SocialPost.new(
      source:      "reddit",
      external_id: "abc123",
      record_type: "submission",
      body:        "NVDA looks bullish"
    )

    assert_not social_post.valid?
    assert_includes social_post.errors[:posted_at], "can't be blank"
  end

  test "requires a valid record type" do
    social_post = SocialPost.new(
      source:      "reddit",
      external_id: "abc123",
      record_type: "invalid",
      body:        "NVDA looks bullish",
      posted_at:   Time.current
    )

    assert_not social_post.valid?
    assert_includes social_post.errors[:record_type], "is not included in the list"
  end

  test "external id must be unique within a source" do
    existing = social_posts(:nvda_post)

    duplicate = SocialPost.new(
      source:      existing.source,
      external_id: existing.external_id,
      record_type: "submission",
      body:        "Duplicate Reddit post",
      posted_at:   Time.current
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end

  test "same external id can exist for different sources" do
    existing = social_posts(:nvda_post)

    social_post = SocialPost.new(
      source:      "discord",
      external_id: existing.external_id,
      record_type: "submission",
      body:        "Same id but different source",
      posted_at:   Time.current
    )

    assert social_post.valid?
  end

  test "submissions scope returns submissions" do
    assert_includes SocialPost.submissions, social_posts(:nvda_post)
    assert_not_includes SocialPost.submissions, social_posts(:nvda_comment)
  end

  test "comments scope returns comments" do
    assert_includes SocialPost.comments, social_posts(:nvda_comment)
    assert_not_includes SocialPost.comments, social_posts(:nvda_post)
  end

  test "comment can resolve its submission" do
    comment = social_posts(:nvda_comment)

    assert_equal social_posts(:nvda_post), comment.submission
  end

  test "comment can resolve its parent" do
    comment = social_posts(:nvda_comment)

    assert_equal social_posts(:nvda_post), comment.parent
  end

  test "submission returns itself as its submission" do
    post = social_posts(:nvda_post)

    assert_equal post, post.submission
  end

  test "with_security_mentions returns posts with matched securities" do
    post = social_posts(:nvda_post)

    assert_includes SocialPost.with_security_mentions, post
  end

  test "without_security_mentions returns posts with no matched securities" do
    post = SocialPost.create!(
      source:      "reddit",
      external_id: "no-security-test",
      record_type: "submission",
      body:        "The overall market seems strange today",
      posted_at:   Time.current
    )

    assert_includes SocialPost.without_security_mentions, post
    assert_not_includes SocialPost.with_security_mentions, post
  end

  test "comment belongs to its submission" do
    comment = social_posts(:nvda_comment)

    assert_equal social_posts(:nvda_post), comment.submission
  end

  test "comment belongs to its parent" do
    comment = social_posts(:nvda_comment)

    assert_equal social_posts(:nvda_post), comment.parent
  end

  test "submission has comments" do
    submission = social_posts(:nvda_post)

    assert_includes submission.comments, social_posts(:nvda_comment)
  end

  test "post has replies" do
    submission = social_posts(:nvda_post)

    assert_includes submission.replies, social_posts(:nvda_comment)
  end

  test "for_subreddit returns posts for that subreddit" do
    post = social_posts(:nvda_post)

    assert_includes SocialPost.for_subreddit("wallstreetbets"), post
  end

  test "for_subreddit excludes posts from other subreddits" do
    post = SocialPost.create!(
      source: "reddit",
      subreddit: "stocks",
      external_id: "stocks-test",
      record_type: "submission",
      body: "NVDA discussion",
      posted_at: Time.current
    )

    assert_not_includes SocialPost.for_subreddit("wallstreetbets"), post
  end
end