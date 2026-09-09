require "test_helper"

module SocialData
  class RedditClientTest < ActiveSupport::TestCase
    test "returns parsed posts from a subreddit" do
      token_response = Net::HTTPSuccess.new(
        "1.1",
        "200",
        "OK"
      )

      token_response.define_singleton_method(:body) do
        {
          access_token: "test-token",
          token_type:   "bearer",
          expires_in:   3600
        }.to_json
      end

      posts_response = Net::HTTPSuccess.new(
        "1.1",
        "200",
        "OK"
      )

      posts_response.define_singleton_method(:body) do
        {
          data: {
            children: [
              {
                data: {
                  id: "abc123",
                  title:       "NVDA calls",
                  selftext:    "NVDA looks bullish",
                  author:      "test_user",
                  score:       100,
                  created_utc: 1_788_940_800
                }
              }
            ]
          }
        }.to_json
      end

      http = Object.new

      http.define_singleton_method(:request) do |request|
        if request.is_a?(Net::HTTP::Post)
          token_response
        else
          posts_response
        end
      end

      Net::HTTP.stub(
        :start,
        ->(*args, **kwargs, &block) { block.call(http) }
      ) do
        data = RedditClient.new(
          client_id: "test-client-id",
          client_secret: "test-client-secret",
          user_agent: "occupy-test"
        ).new_posts(
          subreddit: "wallstreetbets",
          limit: 25
        )

        post = data["data"]["children"].first["data"]

        assert_equal "abc123", post["id"]
        assert_equal "NVDA calls", post["title"]
        assert_equal "test_user", post["author"]
        assert_equal 100, post["score"]
      end
    end

    test "raises when authentication fails" do
      response = Net::HTTPUnauthorized.new(
        "1.1",
        "401",
        "Unauthorized"
      )

      http = Object.new

      http.define_singleton_method(:request) do |request|
        response
      end

      Net::HTTP.stub(
        :start,
        ->(*args, **kwargs, &block) { block.call(http) }
      ) do
        error = assert_raises(RuntimeError) do
          RedditClient.new(
            client_id: "bad-client",
            client_secret: "bad-secret",
            user_agent: "occupy-test"
          ).new_posts(
            subreddit: "wallstreetbets"
          )
        end

        assert_equal(
          "Reddit authentication failed: 401",
          error.message
        )
      end
    end

    test "raises when subreddit request fails" do
      token_response = Net::HTTPSuccess.new(
        "1.1",
        "200",
        "OK"
      )

      token_response.define_singleton_method(:body) do
        {
          access_token: "test-token"
        }.to_json
      end

      failed_response = Net::HTTPServerError.new(
        "1.1",
        "500",
        "Internal Server Error"
      )

      http = Object.new

      http.define_singleton_method(:request) do |request|
        if request.is_a?(Net::HTTP::Post)
          token_response
        else
          failed_response
        end
      end

      Net::HTTP.stub(
        :start,
        ->(*args, **kwargs, &block) { block.call(http) }
      ) do
        error = assert_raises(RuntimeError) do
          RedditClient.new(
            client_id: "test-client-id",
            client_secret: "test-client-secret",
            user_agent: "occupy-test"
          ).new_posts(
            subreddit: "wallstreetbets"
          )
        end

        assert_equal(
          "Reddit request failed: 500",
          error.message
        )
      end
    end
  end
end