require "test_helper"

module MarketData
  class CalculateSecurityDailyOutcomeTest < ActiveSupport::TestCase
    test "calculates forward market outcomes for a daily signal" do
      security = securities(:nvda)

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

      security.market_bars.delete_all

      closes = [
        100,
        102,
        103,
        105,
        104,
        110,
        108,
        107,
        112,
        111,
        115
      ]

      closes.each_with_index do |close, index|
        security.market_bars.create!(
          recorded_at: Date.new(2023, 12, 1) + index.days,
          open: close,
          high: close + 2,
          low: close - 3,
          close: close,
          volume: 1_000_000
        )
      end

      CalculateSecurityDailyOutcome.new(
        security_daily_signal: signal
      ).call

      outcome = SecurityDailyOutcome.find_by!(
        security: security,
        date: signal.date
      )

      assert_equal Date.new(2023, 12, 1), outcome.market_date
      assert_equal 100.0, outcome.price_at_signal.to_f
      assert_equal 2.0, outcome.return_1d.to_f
      assert_equal 5.0, outcome.return_3d.to_f
      assert_equal 10.0, outcome.return_5d.to_f
      assert_equal 15.0, outcome.return_10d.to_f
      assert_equal 17.0, outcome.max_gain_10d.to_f
      assert_equal(-1.0, outcome.max_drawdown_10d.to_f)
    end
  end
end