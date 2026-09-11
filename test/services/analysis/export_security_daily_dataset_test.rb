require "test_helper"
require "tempfile"
require "csv"

module Analysis
  class ExportSecurityDailyDatasetTest < ActiveSupport::TestCase
    test "exports signals with market outcomes and SPY benchmark returns" do
      security = securities(:nvda)
      spy = securities(:spy)

      signal = SecurityDailySignal.create!(
        security: security,
        date: Date.new(2023, 12, 1),
        mention_count: 10,
        submission_count: 2,
        comment_count: 8,
        unique_author_count: 7,
        total_score: 50,
        average_score: 5
      )

      SecurityDailyOutcome.create!(
        security: security,
        date: signal.date,
        market_date: signal.date,
        price_at_signal: 100,
        return_1d: 2,
        return_3d: 3,
        return_5d: 5,
        return_10d: 10,
        max_gain_10d: 12,
        max_drawdown_10d: -4
      )

      spy.market_bars.delete_all

      [
        100,
        101,
        102,
        103,
        104,
        105,
        106,
        107,
        108,
        109,
        110
      ].each_with_index do |close, index|
        spy.market_bars.create!(
          recorded_at: Date.new(2023, 12, 1) + index.days,
          open: close,
          high: close,
          low: close,
          close: close,
          volume: 1_000_000
        )
      end

      file = Tempfile.new(
        ["security_daily_dataset", ".csv"]
      )

      file.close

      ExportSecurityDailyDataset.new(
        path: file.path
      ).call

      rows = CSV.read(
        file.path,
        headers: true
      )

      row = rows.find do |candidate|
        candidate["symbol"] == "NVDA" &&
          candidate["date"] == "2023-12-01"
      end

      assert_not_nil row

      assert_equal "10", row["mention_count"]
      assert_equal "7", row["unique_author_count"]
      assert_equal "5.0", row["return_5d"]

      assert_equal(
        1.0,
        row["spy_return_1d"].to_f
      )

      assert_equal(
        5.0,
        row["spy_return_5d"].to_f
      )

      assert_equal(
        10.0,
        row["spy_return_10d"].to_f
      )
    ensure
      file&.unlink
    end
  end
end