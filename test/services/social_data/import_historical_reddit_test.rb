require "test_helper"
require "tempfile"

module SocialData
  class ImportHistoricalRedditTest < ActiveSupport::TestCase
    test "imports historical Reddit posts" do
      file = create_csv(
        <<~CSV
          external_id,subreddit,record_type,submission_external_id,parent_external_id,author,body,posted_at,score,url
          abc123,wallstreetbets,submission,,,trader_one,NVDA looks bullish,2023-12-01 10:00:00+00,100,https://reddit.com/example
        CSV
      )


      assert_difference -> { SocialPost.count }, 1 do
        ImportHistoricalReddit.new(path: file.path).call
      end

      post = SocialPost.find_by!(
        source:      "reddit",
        external_id: "abc123"
      )

      assert_equal "trader_one", post.author
      assert_equal "NVDA looks bullish", post.body
      assert_equal 100, post.score
      assert_equal "https://reddit.com/example", post.url
      assert_equal "wallstreetbets", post.subreddit
    ensure
      file&.unlink
    end

    test "does not create duplicate posts" do
      file = create_csv(
        <<~CSV
          external_id,author,body,posted_at,score,url
          abc123,trader_one,NVDA looks bullish,2023-12-01 10:00:00+00,100,https://reddit.com/example
        CSV
      )

      importer = ImportHistoricalReddit.new(path: file.path)

      importer.call

      assert_no_difference -> { SocialPost.count } do
        importer.call
      end
    ensure
      file&.unlink
    end

    test "updates an existing post" do
      SocialPost.create!(
        source:      "reddit",
        external_id: "abc123",
        author:      "old_author",
        body:        "Old body",
        posted_at:   Time.zone.parse("2023-12-01 10:00:00"),
        score:       10
      )

      file = create_csv(
        <<~CSV
          external_id,author,body,posted_at,score,url
          abc123,new_author,Updated body,2023-12-01 10:00:00+00,150,https://reddit.com/example
        CSV
      )

      assert_no_difference -> { SocialPost.count } do
        ImportHistoricalReddit.new(path: file.path).call
      end

      post = SocialPost.find_by!(
        source:      "reddit",
        external_id: "abc123"
      )

      assert_equal "new_author", post.author
      assert_equal "Updated body", post.body
      assert_equal 150, post.score
    ensure
      file&.unlink
    end

    test "raises when file does not exist" do
      error = assert_raises(RuntimeError) do
        ImportHistoricalReddit.new(
          path: "/does/not/exist.csv"
        ).call
      end

      assert_equal(
        "File not found: /does/not/exist.csv",
        error.message
      )
    end

    test "imports historical Reddit comments" do
      file = create_csv(
        <<~CSV
          external_id,subreddit,record_type,submission_external_id,parent_external_id,author,body,posted_at,score,url
          comment123,wallstreetbets,comment,submission123,submission123,trader_one,NVDA looks strong,2023-12-01 10:15:00+00,25,https://reddit.com/example/comment
        CSV
      )

      assert_difference -> { SocialPost.count }, 1 do
        ImportHistoricalReddit.new(
          path: file.path
        ).call
      end

      comment = SocialPost.find_by!(
        source: "reddit",
        external_id: "comment123"
      )

      assert_equal "comment", comment.record_type
      assert_equal "submission123", comment.submission_external_id
      assert_equal "submission123", comment.parent_external_id
      assert_equal "NVDA looks strong", comment.body
      assert_equal 25, comment.score
    ensure
      file&.unlink
    end

    test "imports records across multiple batches" do
      file = Tempfile.new(
        ["historical_reddit", ".csv"]
      )

      file.write(
        "external_id,subreddit,record_type,submission_external_id,parent_external_id,author,body,posted_at,score,url\n"
      )

      1_001.times do |index|
        file.write(
          "batch#{index},wallstreetbets,comment,submission1,submission1,user#{index},Body #{index},2023-12-01 10:00:00+00,1,https://reddit.com/example/#{index}\n"
        )
      end

      file.close

      assert_difference -> { SocialPost.count }, 1_001 do
        ImportHistoricalReddit.new(
          path: file.path
        ).call
      end
    ensure
      file&.unlink
    end

    test "extracts security mentions for imported posts" do
      file = Tempfile.new(
        ["historical_reddit", ".csv"]
      )

      file.write(
        <<~CSV
          external_id,subreddit,record_type,submission_external_id,parent_external_id,author,body,posted_at,score,url
          ticker123,wallstreetbets,submission,,,trader_one,$NVDA looks strong,2023-12-01 10:00:00+00,10,https://reddit.com/example
        CSV
      )

      file.close

      assert_difference -> { SecurityMention.count }, 1 do
        ImportHistoricalReddit.new(
          path: file.path
        ).call
      end

      post = SocialPost.find_by!(
        source: "reddit",
        external_id: "ticker123"
      )

      assert_equal ["NVDA"], post.securities.pluck(:symbol)
    ensure
      file&.unlink
    end

    private

    def create_csv(contents)
      file = Tempfile.new(
        ["historical_reddit", ".csv"]
      )

      file.write(contents)
      file.close

      file
    end
  end
end