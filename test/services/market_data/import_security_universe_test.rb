require "test_helper"

module MarketData
  class ImportSecurityUniverseTest < ActiveSupport::TestCase
    test "imports Nasdaq securities and skips test issues" do
      importer = ImportSecurityUniverse.new

      nasdaq_data = <<~DATA
        Symbol|Security Name|Market Category|Test Issue|Financial Status|Round Lot Size|ETF|NextShares
        AAPL|Apple Inc. - Common Stock|Q|N|N|100|N|N
        TESTZ|Test Security|Q|Y|N|100|N|N
        File Creation Time: 0910202617:00|||||||
      DATA

      other_data = <<~DATA
        ACT Symbol|Security Name|Exchange|CQS Symbol|ETF|Round Lot Size|Test Issue|NASDAQ Symbol
        GME|GameStop Corp. Class A|N|GME|N|100|N|GME
        SPY|SPDR S&P 500 ETF Trust|P|SPY|Y|100|N|SPY
        File Creation Time: 0910202617:00|||||||
      DATA

      importer.stub(:fetch_rows, ->(url) {
        body = url == ImportSecurityUniverse::NASDAQ_URL ? nasdaq_data : other_data

        CSV.parse(
          body,
          headers: true,
          col_sep: "|"
        )
      }) do
        importer.call
      end

      aapl = Security.find_by!(symbol: "AAPL")
      gme  = Security.find_by!(symbol: "GME")
      spy  = Security.find_by!(symbol: "SPY")

      assert_equal "NASDAQ", aapl.exchange
      assert_equal "stock", aapl.security_type

      assert_equal "NYSE", gme.exchange
      assert_equal "stock", gme.security_type

      assert_equal "NYSE Arca", spy.exchange
      assert_equal "etf", spy.security_type

      assert_nil Security.find_by(symbol: "TESTZ")
    end

    test "updates existing securities without creating duplicates" do
      Security.create!(
        symbol:        "AAPL",
        name:          "Old Apple",
        security_type: "stock",
        exchange:      "NASDAQ",
        is_active:      true
      )

      importer = ImportSecurityUniverse.new

      nasdaq_data = <<~DATA
        Symbol|Security Name|Market Category|Test Issue|Financial Status|Round Lot Size|ETF|NextShares
        AAPL|Apple Inc. - Common Stock|Q|N|N|100|N|N
        File Creation Time: 0910202617:00|||||||
      DATA

      other_data = <<~DATA
        ACT Symbol|Security Name|Exchange|CQS Symbol|ETF|Round Lot Size|Test Issue|NASDAQ Symbol
        File Creation Time: 0910202617:00|||||||
      DATA

      importer.stub(:fetch_rows, ->(url) {
        body = url == ImportSecurityUniverse::NASDAQ_URL ? nasdaq_data : other_data

        CSV.parse(
          body,
          headers: true,
          col_sep: "|"
        )
      }) do
        assert_no_difference -> { Security.where(symbol: "AAPL").count } do
          importer.call
        end
      end

      assert_equal(
        "Apple Inc. - Common Stock",
        Security.find_by!(symbol: "AAPL").name
      )
    end
  end
end