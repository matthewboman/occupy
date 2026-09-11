require "test_helper"

module MarketData
  class TradingCalendarTest < ActiveSupport::TestCase
    test "market is open on a normal weekday" do
      assert TradingCalendar.open?(
        Date.new(2023, 12, 22)
      )
    end

    test "market is closed on saturday" do
      assert_not TradingCalendar.open?(
        Date.new(2023, 12, 23)
      )
    end

    test "market is closed on sunday" do
      assert_not TradingCalendar.open?(
        Date.new(2023, 12, 24)
      )
    end

    test "market is closed on christmas" do
      assert_not TradingCalendar.open?(
        Date.new(2023, 12, 25)
      )
    end

    test "market is closed on new years day" do
      assert_not TradingCalendar.open?(
        Date.new(2024, 1, 1)
      )
    end

    test "market is closed on mlk day" do
      assert_not TradingCalendar.open?(
        Date.new(2024, 1, 15)
      )
    end

    test "market is closed on presidents day" do
      assert_not TradingCalendar.open?(
        Date.new(2024, 2, 19)
      )
    end

    test "market is closed on good friday" do
      assert_not TradingCalendar.open?(
        Date.new(2024, 3, 29)
      )
    end

    test "market is closed on thanksgiving" do
      assert_not TradingCalendar.open?(
        Date.new(2024, 11, 28)
      )
    end
  end
end