namespace :market_data do
  desc "Audit existing market bars and persist suspicion flags"
  task audit: :environment do
    reviewed_count = 0
    suspicious_count = 0
    invalid_count = 0

    Security
      .joins(:market_bars)
      .distinct
      .find_each do |security|

      bars = security
        .market_bars
        .order(:recorded_at)
        .to_a

      bars_by_date = bars.group_by {
        |bar| bar.recorded_at.to_date
      }

      updates = []

      bars.each_with_index do |bar, index|
        invalid_reasons = []
        suspicion_reasons = []

        date = bar.recorded_at.to_date

        open = bar.open.to_d
        high = bar.high.to_d
        low = bar.low.to_d
        close = bar.close.to_d
        volume = bar.volume.to_i

        unless MarketData::TradingCalendar.open?(date)
          invalid_reasons << "closed_market_date"
        end

        if [
          open,
          high,
          low,
          close
        ].any? { |value| value <= 0 }
          invalid_reasons << "non_positive_ohlc"
        end

        if volume.negative?
          invalid_reasons << "negative_volume"
        end

        if high < low
          invalid_reasons << "high_below_low"
        end

        if open > high || open < low
          invalid_reasons << "open_outside_range"
        end

        if close > high || close < low
          suspicion_reasons << "close_outside_range"
        end

        if bars_by_date[date].length > 1
          suspicion_reasons << "duplicate_calendar_date"
        end

        previous_bar = index.zero? ? nil : bars[index - 1]

        if previous_bar&.close.present? &&
           !previous_bar.close.zero?

          move = (
            (close - previous_bar.close.to_d) /
            previous_bar.close.to_d *
            100
          )

          if move.abs >= 100
            suspicion_reasons <<(
              "one_day_move_#{move.round(2)}pct"
            )
          end
        end

        reasons = (
          invalid_reasons +
          suspicion_reasons
        )

        suspicious = suspicion_reasons.present?

        reviewed_count += 1

        if invalid_reasons.present?
          invalid_count += 1

          puts [
            "INVALID",
            security.symbol,
            date,
            reasons.join(", ")
          ].join(" | ")
        end

        if suspicious
          suspicious_count += 1

          puts [
            "SUSPICIOUS",
            security.symbol,
            date,
            suspicion_reasons.join(", ")
          ].join(" | ")
        end

        updates << {
          id: bar.id,
          suspicious: suspicious,
          suspicion_reasons: reasons
        }
      end

      updates.each do |attributes|
        MarketBar
          .where(id: attributes[:id])
          .update_all(
            suspicious: attributes[:suspicious],
            suspicion_reasons: attributes[:suspicion_reasons]
          )
      end
    end

    puts
    puts "Reviewed bars: #{reviewed_count}"
    puts "Suspicious bars: #{suspicious_count}"
    puts "Invalid bars: #{invalid_count}"
  end
end