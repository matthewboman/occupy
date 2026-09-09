require "net/http"
require "json"
require "base64"

module SocialData
  class RedditClient
    TOKEN_URL = "https://www.reddit.com/api/v1/access_token"
    API_URL   = "https://oauth.reddit.com"

    def initialize(
      client_id: Rails.application.credentials.dig(:reddit, :client_id),
      client_secret: Rails.application.credentials.dig(:reddit, :client_secret),
      user_agent: Rails.application.credentials.dig(:reddit, :user_agent)
    )
      @client_id = client_id
      @client_secret = client_secret
      @user_agent = user_agent
    end

    def new_posts(subreddit:, limit: 100)
      token = access_token

      uri = URI(
        "#{API_URL}/r/#{subreddit}/new"
      )

      uri.query = URI.encode_www_form(
        limit: limit,
        raw_json: 1
      )

      request = Net::HTTP::Get.new(uri)

      request["Authorization"] = "Bearer #{token}"
      request["User-Agent"] = @user_agent

      response = Net::HTTP.start(
        uri.hostname,
        uri.port,
        use_ssl: true
      ) do |http|
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise "Reddit request failed: #{response.code}"
      end

      JSON.parse(response.body)
    end

    private

    def access_token
      uri = URI(TOKEN_URL)

      request = Net::HTTP::Post.new(uri)

      request["Authorization"] = basic_auth
      request["User-Agent"] = @user_agent
      request["Content-Type"] = "application/x-www-form-urlencoded"

      request.body = URI.encode_www_form(
        grant_type: "client_credentials"
      )

      response = Net::HTTP.start(
        uri.hostname,
        uri.port,
        use_ssl: true
      ) do |http|
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise "Reddit authentication failed: #{response.code}"
      end

      data = JSON.parse(response.body)

      data.fetch("access_token")
    end

    def basic_auth
      credentials = Base64.strict_encode64(
        "#{@client_id}:#{@client_secret}"
      )

      "Basic #{credentials}"
    end
  end
end