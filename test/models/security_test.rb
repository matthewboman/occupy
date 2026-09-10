require "test_helper"

class SecurityTest < ActiveSupport::TestCase
  setup do
    @security = securities(:nvda)

    @security.market_bars.delete_all

    [
      ["2026-09-01", 100.0, 1_000],
      ["2026-09-02", 102.0, 1_100],
      ["2026-09-03", 101.0, 1_200],
      ["2026-09-04", 104.0, 1_300],
      ["2026-09-05", 106.0, 1_500],
      ["2026-09-08", 110.0, 2_000]
    ].each do |date, close, volume|
      @security.market_bars.create!(
        recorded_at: Time.zone.parse(date),
        open:        close,
        high:        close,
        low:         close,
        close:       close,
        volume:      volume
      )
    end
  end

  test "returns latest market bar" do
    assert_equal(
      Date.new(2026, 9, 8),
      @security.latest_market_bar.recorded_at.to_date
    )
  end

  test "calculates one day return" do
    assert_in_delta(
      3.7736,
      @security.return_for_days(1),
      0.0001
    )
  end

  test "calculates five day return" do
    assert_in_delta(
      10.0,
      @security.return_for_days(5),
      0.0001
    )
  end

  test "calculates volume change" do
    assert_in_delta(
      33.3333,
      @security.volume_change,
      0.0001
    )
  end

  test "returns nil when there is not enough price history" do
    @security.market_bars.delete_all

    @security.market_bars.create!(
      recorded_at: Time.zone.parse("2026-09-08"),
      open:        100,
      high:        100,
      low:         100,
      close:       100,
      volume:      1_000
    )

    assert_nil @security.return_for_days(1)
  end

  test "has social posts" do
    social_post = social_posts(:nvda_post)

    assert_includes @security.social_posts, social_post
  end
end