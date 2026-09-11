module MarketData
  class BarValidator
    Result = Struct.new(
      :valid,
      :suspicious,
      :reasons,
      keyword_init: true
    )

    LARGE_MOVE_PERCENT = 100

    def initialize(
      security:,
      recorded_at:,
      open:,
      high:,
      low:,
      close:,
      volume:
    )
      @security = security
      @recorded_at = recorded_at
      @date = recorded_at.to_date
      @open = open.to_d
      @high = high.to_d
      @low = low.to_d
      @close = close.to_d
      @volume = volume.to_i
    end

    def call
      invalid_reasons = []
      suspicion_reasons = []

      invalid_reasons << "closed_market_date" unless TradingCalendar.open?(@date)

      invalid_reasons << "non_positive_ohlc" if [
        @open,
        @high,
        @low,
        @close
      ].any? { |value| value <= 0 }

      invalid_reasons << "negative_volume" if @volume.negative?
      invalid_reasons << "high_below_low" if @high < @low

      if @open > @high || @open < @low
        invalid_reasons << "open_outside_range"
      end

      if @close > @high || @close < @low
        suspicion_reasons << "close_outside_range"
      end

      if duplicate_calendar_date?
        suspicion_reasons << "duplicate_calendar_date"
      end

      move = one_day_move_percent

      if move.present? && move.abs >= LARGE_MOVE_PERCENT
        suspicion_reasons << "one_day_move_#{move.round(2)}pct"
      end

      Result.new(
        valid: invalid_reasons.empty?,
        suspicious: suspicion_reasons.present?,
        reasons: invalid_reasons + suspicion_reasons
      )
    end

    private

    def duplicate_calendar_date?
      @security
        .market_bars
        .where(recorded_at: @date.all_day)
        .where.not(recorded_at: @recorded_at)
        .exists?
    end

    def previous_bar
      @previous_bar ||= @security
        .market_bars
        .where("recorded_at < ?", @recorded_at)
        .order(recorded_at: :desc)
        .first
    end

    def one_day_move_percent
      previous_close = previous_bar&.close

      return if previous_close.blank?
      return if previous_close.zero?

      (
        (@close - previous_close.to_d) /
        previous_close.to_d *
        100
      )
    end
  end
end