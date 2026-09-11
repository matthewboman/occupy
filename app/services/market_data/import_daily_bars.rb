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

      rows = bars.filter_map do |bar|
        recorded_at = Time.zone.parse(
          bar.fetch("date")
        )

        validation = MarketData::BarValidator.new(
          security:    @security,
          recorded_at: recorded_at,
          open:        bar.fetch("open"),
          high:        bar.fetch("high"),
          low:         bar.fetch("low"),
          close:       bar.fetch("close"),
          volume:      bar.fetch("volume")
        ).call

        unless validation.valid
          Rails.logger.warn(
            "Rejected market bar " \
            "#{@security.symbol} " \
            "#{recorded_at.to_date}: " \
            "#{validation.reasons.join(", ")}"
          )

          next
        end

        if validation.suspicious
          Rails.logger.warn(
            "Suspicious market bar " \
            "#{@security.symbol} " \
            "#{recorded_at.to_date}: " \
            "#{validation.reasons.join(", ")}"
          )
        end

        {
          security_id:       @security.id,
          recorded_at:       recorded_at,
          open:              bar.fetch("open"),
          high:              bar.fetch("high"),
          low:               bar.fetch("low"),
          close:             bar.fetch("close"),
          volume:            bar.fetch("volume"),
          suspicious:        validation.suspicious,
          suspicion_reasons: validation.reasons,
          created_at:        Time.current,
          updated_at:        Time.current
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
          :volume,
          :suspicious,
          :suspicion_reasons
        ]
      )
    end
  end
end