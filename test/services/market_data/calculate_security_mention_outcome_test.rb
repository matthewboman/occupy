require "test_helper"

module MarketData
  class CalculateSecurityMentionOutcomeTest < ActiveSupport::TestCase
    test "calculates forward returns and ten day range" do
      security = securities(:nvda)
      post = social_posts(:nvda_post)
      mention = security_mentions(:nvda_mention)

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
          recorded_at: (
            post.posted_at.to_date +
            index.days
          ),
          open: close,
          high: close + 2,
          low: close - 3,
          close: close,
          volume: 1_000_000
        )
      end

      CalculateSecurityMentionOutcome.new(
        security_mention: mention
      ).call

      outcome = mention.reload.security_mention_outcome

      assert_equal 100.0, outcome.price_at_mention.to_f
      assert_equal 2.0, outcome.return_1d.to_f
      assert_equal 5.0, outcome.return_3d.to_f
      assert_equal 10.0, outcome.return_5d.to_f
      assert_equal 15.0, outcome.return_10d.to_f
      assert_equal 17.0, outcome.max_gain_10d.to_f
      assert_equal(-1.0, outcome.max_drawdown_10d.to_f)
    end

    test "uses same day for a mention before market close" do
      security = securities(:nvda)
      mention = security_mentions(:nvda_mention)

      mention.social_post.update!(
        posted_at: Time.zone.parse("2023-12-01 15:00:00 -0500")
      )

      security.market_bars.delete_all

      security.market_bars.create!(
        recorded_at: Time.zone.parse("2023-12-01"),
        open: 100,
        high: 105,
        low: 95,
        close: 102,
        volume: 1_000_000
      )

      CalculateSecurityMentionOutcome.new(
        security_mention: mention
      ).call

      assert_equal(
        Date.new(2023, 12, 1),
        mention.reload.security_mention_outcome.market_date
      )
    end

    test "uses next trading day for a mention after market close" do
      security = securities(:nvda)
      mention = security_mentions(:nvda_mention)

      mention.social_post.update!(
        posted_at: Time.zone.parse("2023-12-01 17:00:00 -0500")
      )

      security.market_bars.delete_all

      security.market_bars.create!(
        recorded_at: Time.zone.parse("2023-12-04"),
        open: 100,
        high: 105,
        low: 95,
        close: 102,
        volume: 1_000_000
      )

      CalculateSecurityMentionOutcome.new(
        security_mention: mention
      ).call

      assert_equal(
        Date.new(2023, 12, 4),
        mention.reload.security_mention_outcome.market_date
      )
    end

  end
end