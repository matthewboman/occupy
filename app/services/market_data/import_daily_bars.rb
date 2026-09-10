module MarketData
  class ImportDailyBars
    def initialize(
      security:,
      client:     StashGammaClient.new,
      start_date: Date.new(2023, 12, 1),
      end_date:   Date.current
    )
      @security = security
      @client = client
      @start_date = start_date
      @end_date = end_date
    end

    def call
      data = @client.daily(
        symbol: @security.symbol,
        from:   @start_date.to_s,
        to:     @end_date.to_s
      )

      bars = data.fetch(
        "bars"
      )

      rows = bars.map do |bar|
        {
          security_id: @security.id,
          recorded_at: Time.zone.parse( bar.fetch("date")),
          open:        bar.fetch("open"),
          high:        bar.fetch("high"),
          low:         bar.fetch("low"),
          close:       bar.fetch("close"),
          volume:      bar.fetch("volume"),
          created_at:  Time.current,
          updated_at:  Time.current
        }
      end

      return if rows.empty?

      MarketBar.upsert_all(
        rows,
        unique_by: [
          :security_id,
          :recorded_at
        ],
        update_only: [
          :open,
          :high,
          :low,
          :close,
          :volume
        ]
      )
    end
  end
end