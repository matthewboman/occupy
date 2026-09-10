require "csv"
require "net/http"

module MarketData
  class ImportSecurityUniverse
    NASDAQ_URL = "https://www.nasdaqtrader.com/dynamic/SymDir/nasdaqlisted.txt"
    OTHER_URL  = "https://www.nasdaqtrader.com/dynamic/SymDir/otherlisted.txt"

    EXCHANGES = {
      "A" => "NYSE American",
      "N" => "NYSE",
      "P" => "NYSE Arca",
      "Z" => "Cboe BZX",
      "V" => "IEX"
    }.freeze

    def call
      import_nasdaq
      import_other
    end

    private

    def import_nasdaq
      rows = fetch_rows(NASDAQ_URL)

      rows.each do |row|
        next if row["Symbol"].blank?
        next if row["Symbol"].start_with?("File Creation Time")
        next if row["Test Issue"] == "Y"

        upsert_security(
          symbol:        row["Symbol"],
          name:          row["Security Name"],
          exchange:      "NASDAQ",
          security_type: "stock"
        )
      end
    end

    def import_other
      rows = fetch_rows(OTHER_URL)

      rows.each do |row|
        next if row["ACT Symbol"].blank?
        next if row["ACT Symbol"].start_with?("File Creation Time")
        next if row["Test Issue"] == "Y"

        upsert_security(
          symbol:        row["ACT Symbol"],
          name:          row["Security Name"],
          exchange:      EXCHANGES[row["Exchange"]] || row["Exchange"],
          security_type: row["ETF"] == "Y" ? "etf" : "stock"
        )
      end
    end

    def fetch_rows(url)
      uri = URI(url)

      response = Net::HTTP.start(
        uri.hostname,
        uri.port,
        use_ssl:      true,
        open_timeout: 15,
        read_timeout: 30
      ) do |http|
        http.get(uri.request_uri)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise "Security universe request failed: #{response.code}"
      end

      CSV.parse(
        response.body,
        headers: true,
        col_sep: "|"
      )
    end

    def upsert_security(symbol:, name:, exchange:, security_type:)
      security = Security.find_or_initialize_by(symbol: symbol)

      security.update!(
        name:          name,
        exchange:      exchange,
        security_type: security_type,
        is_active:     true
      )
    end
  end
end