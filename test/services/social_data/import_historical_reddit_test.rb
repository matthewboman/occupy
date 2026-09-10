require "test_helper"
require "tempfile"

module SocialData
  class ImportHistoricalRedditTest < ActiveSupport::TestCase
    test "imports historical Reddit posts" do
      file = create_csv(
        <<~CSV
          external_id,author,body,posted_at,score,url
          abc123,trader_one,NVDA looks bullish,2023-12-01 10:00:00+00,100,https://reddit.com/example
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