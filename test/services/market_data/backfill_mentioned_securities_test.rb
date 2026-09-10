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
            "completed_symbols" => []
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

      state = JSON.parse(
        File.read(state_file.path)
      )

      assert_equal(
        ["GME", "NVDA"],
        state["completed_symbols"].sort
      )
    ensure
      state_file&.unlink
    end

    test "skips securities already completed" do
      nvda = securities(:nvda)

      requested_symbols = []

      client = Object.new

      client.define_singleton_method(:daily) do |symbol:, from:, to:|
        requested_symbols << symbol

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
            "completed_symbols" => [
              nvda.symbol
            ]
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

      assert_not_includes(
        requested_symbols,
        nvda.symbol
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
            "completed_symbols" => []
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

      assert_not_includes(
        state["completed_symbols"],
        gme.symbol
      )
    ensure
      state_file&.unlink
    end

  end
end