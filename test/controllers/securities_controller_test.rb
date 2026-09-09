require "test_helper"

class SecuritiesControllerTest < ActionDispatch::IntegrationTest
  test "shows a security" do
    security = securities(:nvda)

    get security_path(security)

    assert_response :success
    assert_select "h1", "NVDA"
    assert_select "h2", "Market History"
  end

  test "shows market bars newest first" do
    security = securities(:nvda)

    older = security.market_bars.create!(
      recorded_at: Time.zone.parse("2026-09-08"),
      open: 170.00,
      high: 175.00,
      low: 169.00,
      close: 174.00,
      volume: 100_000_000
    )

    newer = security.market_bars.create!(
      recorded_at: Time.zone.parse("2026-09-09"),
      open: 174.00,
      high: 178.00,
      low: 173.00,
      close: 177.00,
      volume: 120_000_000
    )

    get security_path(security)

    assert_response :success

    dates = css_select("tbody tr td:first-child").map(&:text)

    assert_equal newer.recorded_at.to_date.to_s, dates.first
    assert_equal older.recorded_at.to_date.to_s, dates.second
  end

  test "shows market analytics" do
    security = securities(:nvda)

    security.market_bars.delete_all

    security.market_bars.create!(
      recorded_at: Time.zone.parse("2026-09-08"),
      open: 100,
      high: 100,
      low: 100,
      close: 100,
      volume: 1_000
    )

    security.market_bars.create!(
      recorded_at: Time.zone.parse("2026-09-09"),
      open: 110,
      high: 110,
      low: 110,
      close: 110,
      volume: 1_500
    )

    get security_path(security)

    assert_response :success
    assert_select "h2", text: "Market Analytics"
    assert_select "td", text: "10.00%"
    assert_select "td", text: "50.00%"
  end
end