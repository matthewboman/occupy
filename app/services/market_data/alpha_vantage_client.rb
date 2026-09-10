require "net/http"
require "json"

module MarketData
  class AlphaVantageClient
    BASE_URL = "https://www.alphavantage.co/query"

    def initialize(
      api_key: Rails.application.credentials.dig(
        :alpha_vantage,
        :api_key
      )
    )
      @api_key = api_key
    end

    def daily(symbol:)
      uri = URI(BASE_URL)

      uri.query = URI.encode_www_form(
        function:   "TIME_SERIES_DAILY",
        symbol:     symbol,
        outputsize: "full",
        apikey:     @api_key
      )

      response = Net::HTTP.get_response(uri)

      unless response.is_a?(Net::HTTPSuccess)
        raise "Alpha Vantage request failed: #{response.code}"
      end

      JSON.parse(response.body)
    end
  end
end