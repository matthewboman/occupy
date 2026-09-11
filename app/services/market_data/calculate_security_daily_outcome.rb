module MarketData
  class CalculateSecurityDailyOutcome
    WINDOW = 10

    def initialize(security_daily_signal:)
      @signal = security_daily_signal
      @security = security_daily_signal.security
    end

    def call
      bars = relevant_bars

      return if bars.empty?

      entry_bar   = bars.first
      entry_price = entry_bar.close.to_d

      return if entry_price.zero?

      SecurityDailyOutcome.upsert(
        {
          security_id:      @security.id,
          date:             @signal.date,
          market_date:      entry_bar.recorded_at.to_date,
          price_at_signal:  entry_price,
          return_1d:        forward_return(bars, entry_price, 1),
          return_3d:        forward_return(bars, entry_price, 3),
          return_5d:        forward_return(bars, entry_price, 5),
          return_10d:       forward_return(bars, entry_price, 10),
          max_gain_10d:     max_gain(bars, entry_price),
          max_drawdown_10d: max_drawdown(bars, entry_price),
          created_at:       Time.current,
          updated_at:       Time.current
        },
        unique_by: [:security_id, :date]
      )
    end

    private

    def relevant_bars
      @security.market_bars
               .where(
                 "recorded_at >= ?",
                 @signal.date.beginning_of_day
               )
               .order(:recorded_at)
               .limit(WINDOW + 1)
               .to_a
    end

    def forward_return(bars, entry_price, days)
      bar = bars[days]

      return if bar.nil?

      percentage_change(
        entry_price,
        bar.close.to_d
      )
    end

    def max_gain(bars, entry_price)
      future_bars = bars.drop(1).first(WINDOW)

      return if future_bars.empty?

      highest = future_bars
                  .map { |bar| bar.high.to_d }
                  .max

      percentage_change(
        entry_price,
        highest
      )
    end

    def max_drawdown(bars, entry_price)
      future_bars = bars.drop(1).first(WINDOW)

      return if future_bars.empty?

      lowest = future_bars
                 .map { |bar| bar.low.to_d }
                 .min

      percentage_change(
        entry_price,
        lowest
      )
    end

    def percentage_change(start_price, end_price)
      (
        (end_price - start_price) /
        start_price *
        100
      ).round(6)
    end
  end
end