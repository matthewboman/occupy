require "test_helper"

module MarketData
  class AlphaVantageClientTest < ActiveSupport::TestCase
    test "returns parsed daily market data" do
      response = Net::HTTPSuccess.new(
        "1.1",
        "200",
        "OK"
      )

      body = {
        "Time Series (Daily)" => {
          "2026-09-08" => {
            "1. open" => "170.25",
            "2. high" => "174.10",
            "3. low" => "169.80",
            "4. close" => "173.42",
            "5. volume" => "185000000"
          }
        }
      }.to_json

      response.define_singleton_method(:body) do
        body
      end

      Net::HTTP.stub(:get_response, response) do
        data = AlphaVantageClient.new(
          api_key: "test-key"
        ).daily(
          symbol: "NVDA"
        )

        assert_equal(
          "173.42",
          data["Time Series (Daily)"]["2026-09-08"]["4. close"]
        )
      end
    end

    test "raises when request fails" do
      response = Net::HTTPServerError.new(
        "1.1",
        "500",
        "Internal Server Error"
      )

      Net::HTTP.stub(:get_response, response) do
        error = assert_raises(RuntimeError) do
          AlphaVantageClient.new(
            api_key: "test-key"
          ).daily(
            symbol: "NVDA"
          )
        end

        assert_equal(
          "Alpha Vantage request failed: 500",
          error.message
        )
      end
    end
  end
end