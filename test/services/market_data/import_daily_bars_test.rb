require "test_helper"

module MarketData
  class ImportDailyBarsTest < ActiveSupport::TestCase
    setup do
      @security = securities(:nvda)
    end

    test "imports daily market bars" do
      client = Object.new

      client.define_singleton_method(:daily) do |symbol:|
        raise "Unexpected symbol" unless symbol == "NVDA"

        {
          "Time Series (Daily)" => {
            "2026-09-08" => {
              "1. open" => "170.25",
              "2. high" => "174.10",
              "3. low" => "169.80",
              "4. close" => "173.42",
              "5. volume" => "185000000"
            },
            "2026-09-05" => {
              "1. open" => "168.10",
              "2. high" => "171.00",
              "3. low" => "167.40",
              "4. close" => "170.20",
              "5. volume" => "160000000"
            }
          }
        }
      end

      assert_difference(
        -> { @security.market_bars.count },
        2
      ) do
        ImportDailyBars.new(
          security: @security,
          client: client
        ).call
      end

      bar = @security.market_bars.find_by!(
        recorded_at: Time.zone.parse("2026-09-08")
      )

      assert_equal 170.25, bar.open.to_f
      assert_equal 174.10, bar.high.to_f
      assert_equal 169.80, bar.low.to_f
      assert_equal 173.42, bar.close.to_f
      assert_equal 185_000_000, bar.volume
    end

    test "does not create duplicate bars when imported twice" do
      client = Object.new

      client.define_singleton_method(:daily) do |symbol:|
        raise "Unexpected symbol" unless symbol == "NVDA"

        {
          "Time Series (Daily)" => {
            "2026-09-08" => {
              "1. open" => "170.25",
              "2. high" => "174.10",
              "3. low" => "169.80",
              "4. close" => "173.42",
              "5. volume" => "185000000"
            }
          }
        }
      end

      importer = ImportDailyBars.new(
        security: @security,
        client: client
      )

      importer.call

      assert_no_difference(
        -> { @security.market_bars.count }
      ) do
        importer.call
      end
    end

    test "updates an existing bar when the provider returns new values" do
      @security.market_bars.create!(
        recorded_at: Time.zone.parse("2026-09-08"),
        open:        170.25,
        high:        174.10,
        low:         169.80,
        close:       173.42,
        volume:      185_000_000
      )

      client = Object.new

      client.define_singleton_method(:daily) do |symbol:|
        raise "Unexpected symbol" unless symbol == "NVDA"

        {
          "Time Series (Daily)" => {
            "2026-09-08" => {
              "1. open" => "170.25",
              "2. high" => "175.00",
              "3. low" => "169.80",
              "4. close" => "174.50",
              "5. volume" => "190000000"
            }
          }
        }
      end

      assert_no_difference(
        -> { @security.market_bars.count }
      ) do
        ImportDailyBars.new(
          security: @security,
          client: client
        ).call
      end

      bar = @security.market_bars.find_by!(
        recorded_at: Time.zone.parse("2026-09-08")
      )

      assert_equal 175.00, bar.high.to_f
      assert_equal 174.50, bar.close.to_f
      assert_equal 190_000_000, bar.volume
    end
  end
end