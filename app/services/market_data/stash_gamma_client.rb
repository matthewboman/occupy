require "net/http"
require "json"

module MarketData
  class StashGammaClient
    BASE_URL = "https://www.stashgamma.com/api/dataapi/v1"

    class Error < StandardError
      attr_reader :status_code

      def initialize(message, status_code:)
        super(message)
        @status_code = status_code
      end
    end

    def initialize(
      api_key: Rails.application.credentials.dig(
        :stash_gamma,
        :api_key
      )
    )
      @api_key = api_key
    end

    def daily(symbol:, from:, to:)
      uri = URI(
        "#{BASE_URL}/eod/#{symbol}"
      )

      uri.query = URI.encode_www_form(
        from: from,
        to: to
      )

      request = Net::HTTP::Get.new(uri)
      request["X-Api-Key"] = @api_key

      response = Net::HTTP.start(
        uri.hostname,
        uri.port,
        use_ssl: true
      ) do |http|
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise Error.new(
          "StashGamma request failed: #{response.code} #{response.body}",
          status_code: response.code.to_i
        )
      end

      JSON.parse(response.body)
    end
  end
end