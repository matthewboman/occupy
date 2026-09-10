require "test_helper"

module MarketData
  class ImportDailyBarsTest < ActiveSupport::TestCase
    test "imports daily market bars" do
      security = securities(:nvda)

      client = Object.new

      client.define_singleton_method(:daily) do |symbol:, from:, to:|
        {
          "bars" => [
            {
              "date" => "2023-12-01",
              "open" => 100.0,
              "high" => 110.0,
              "low" => 95.0,
              "close" => 105.0,
              "volume" => 1_000_000
            }
          ]
        }
      end

      assert_difference -> { MarketBar.count }, 1 do
        ImportDailyBars.new(
          security: security,
          client: client
        ).call
      end

      bar = security.market_bars.find_by!(
        recorded_at: Time.zone.parse("2023-12-01")
      )

      assert_equal 100.0, bar.open.to_f
      assert_equal 110.0, bar.high.to_f
      assert_equal 95.0, bar.low.to_f
      assert_equal 105.0, bar.close.to_f
      assert_equal 1_000_000, bar.volume
    end

    test "does not create duplicate bars when imported twice" do
      security = securities(:nvda)

      client = Object.new

      client.define_singleton_method(:daily) do |symbol:, from:, to:|
        {
          "bars" => [
            {
              "date" => "2023-12-01",
              "open" => 100.0,
              "high" => 110.0,
              "low" => 95.0,
              "close" => 105.0,
              "volume" => 1_000_000
            }
          ]
        }
      end

      importer = ImportDailyBars.new(
        security: security,
        client: client
      )

      importer.call

      assert_no_difference -> { MarketBar.count } do
        importer.call
      end
    end

    test "updates an existing bar when the provider returns new values" do
      security = securities(:nvda)

      responses = [
        {
          "bars" => [
            {
              "date" => "2023-12-01",
              "open" => 100.0,
              "high" => 110.0,
              "low" => 95.0,
              "close" => 105.0,
              "volume" => 1_000_000
            }
          ]
        },
        {
          "bars" => [
            {
              "date" => "2023-12-01",
              "open" => 100.0,
              "high" => 112.0,
              "low" => 95.0,
              "close" => 108.0,
              "volume" => 1_250_000
            }
          ]
        }
      ]

      client = Object.new

      client.define_singleton_method(:daily) do |symbol:, from:, to:|
        responses.shift
      end

      importer = ImportDailyBars.new(
        security: security,
        client: client
      )

      importer.call
      importer.call

      bar = security.market_bars.find_by!(
        recorded_at: Time.zone.parse("2023-12-01")
      )

      assert_equal 112.0, bar.high.to_f
      assert_equal 108.0, bar.close.to_f
      assert_equal 1_250_000, bar.volume
    end
  end
end