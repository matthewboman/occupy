module MarketData
  class ImportDailyBars
    TIME_SERIES_KEY = "Time Series (Daily)"

    def initialize(
      security:,
      client: AlphaVantageClient.new
    )
      @security = security
      @client = client
    end

    def call
      data = @client.daily(
        symbol: @security.symbol
      )

      bars = data.fetch(
        TIME_SERIES_KEY
      )

      bars.each do |date, values|
        @security.market_bars
                 .find_or_initialize_by(
                   recorded_at: Time.zone.parse(date)
                 )
                 .update!(
                   open: values.fetch("1. open"),
                   high: values.fetch("2. high"),
                   low: values.fetch("3. low"),
                   close: values.fetch("4. close"),
                   volume: values.fetch("5. volume")
                 )
      end
    end
  end
end