require "test_helper"
require "tempfile"

module MarketData
  class BackfillMentionedSecuritiesTest < ActiveSupport::TestCase
    test "backfills securities mentioned in social posts" do
      nvda = securities(:nvda)
      gme = securities(:gme)

      responses = {
        "NVDA" => {
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
        "GME" => {
          "bars" => [
            {
              "date" => "2023-12-01",
              "open" => 20.0,
              "high" => 22.0,
              "low" => 19.0,
              "close" => 21.0,
              "volume" => 500_000
            }
          ]
        }
      }

      requested_symbols = []

      client = Object.new

      client.define_singleton_method(:daily) do |symbol:, from:, to:|
        requested_symbols << symbol

        responses.fetch(symbol)
      end

      state_file = Tempfile.new(
        ["market_backfill_state", ".json"]
      )

      state_file.write(
        JSON.generate(
          {
            "unavailable_symbols" => []
          }
        )
      )

      state_file.close

      BackfillMentionedSecurities.new(
        client: client,
        request_delay: 0,
        state_path: state_file.path,
        min_mentions: 1
      ).call

      assert MarketBar.exists?(
        security: nvda,
        recorded_at: Time.zone.parse("2023-12-01")
      )

      assert MarketBar.exists?(
        security: gme,
        recorded_at: Time.zone.parse("2023-12-01")
      )

      assert_equal(
        ["GME", "NVDA"],
        requested_symbols.sort
      )
    ensure
      state_file&.unlink
    end

    test "resumes from the day after the latest market bar" do
      nvda = securities(:nvda)

      MarketBar.create!(
        security: nvda,
        recorded_at: Time.zone.parse("2024-02-29"),
        open: 100,
        high: 110,
        low: 95,
        close: 105,
        volume: 1_000_000
      )

      requests = []

      client = Object.new

      client.define_singleton_method(:daily) do |symbol:, from:, to:|
        requests << {
          symbol: symbol,
          from: from,
          to: to
        }

        {
          "bars" => []
        }
      end

      state_file = Tempfile.new(
        ["market_backfill_state", ".json"]
      )

      state_file.write(
        JSON.generate(
          {
            "unavailable_symbols" => []
          }
        )
      )

      state_file.close

      BackfillMentionedSecurities.new(
        client: client,
        end_date: Date.new(2024, 3, 31),
        request_delay: 0,
        state_path: state_file.path,
        min_mentions: 1
      ).call

      nvda_request = requests.find do |request|
        request[:symbol] == nvda.symbol
      end

      assert_equal(
        "2024-03-01",
        nvda_request[:from]
      )

      assert_equal(
        "2024-03-31",
        nvda_request[:to]
      )
    ensure
      state_file&.unlink
    end

    test "marks securities unavailable when provider returns 404" do
      gme = securities(:gme)

      client = Object.new

      client.define_singleton_method(:daily) do |symbol:, from:, to:|
        if symbol == gme.symbol
          raise StashGammaClient::Error.new(
            "StashGamma request failed: 404",
            status_code: 404
          )
        end

        {
          "bars" => []
        }
      end

      state_file = Tempfile.new(
        ["market_backfill_state", ".json"]
      )

      state_file.write(
        JSON.generate(
          {
            "unavailable_symbols" => []
          }
        )
      )

      state_file.close

      BackfillMentionedSecurities.new(
        client: client,
        request_delay: 0,
        state_path: state_file.path,
        min_mentions: 1
      ).call

      state = JSON.parse(
        File.read(state_file.path)
      )

      assert_includes(
        state["unavailable_symbols"],
        gme.symbol
      )
    ensure
      state_file&.unlink
    end
  end
end