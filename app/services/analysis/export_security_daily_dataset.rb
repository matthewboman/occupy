require "csv"

module Analysis
  class ExportSecurityDailyDataset
    WINDOWS = [1, 3, 5, 10].freeze

    def initialize(path:)
      @path = Pathname.new(path)
      @spy = Security.find_by!(symbol: "SPY")
      @spy_returns = {}
    end

    def call
      @path.dirname.mkpath

      CSV.open(@path, "w") do |csv|
        csv << headers

        dataset.find_each do |signal|
          outcome = signal
            .security
            .security_daily_outcomes
            .find_by(date: signal.date)

          next unless outcome

          spy = spy_returns(signal.date)

          past_range_10d = past_range(
            signal.security,
            outcome
          )

          csv << [
            signal.security.symbol,
            signal.date,
            signal.mention_count,
            signal.submission_count,
            signal.comment_count,
            signal.unique_author_count,
            signal.total_score,
            signal.average_score,
            outcome.market_date,
            outcome.price_at_signal,
            outcome.return_1d,
            outcome.return_3d,
            outcome.return_5d,
            outcome.return_10d,
            spy[:return_1d],
            spy[:return_3d],
            spy[:return_5d],
            spy[:return_10d],
            past_range_10d,
            outcome.max_gain_10d,
            outcome.max_drawdown_10d
          ]
        end
      end
    end

    private

    def dataset
      SecurityDailySignal.includes(
        security: :security_daily_outcomes
      )
    end

    def spy_returns(date)
      @spy_returns[date] ||= begin
        bars = @spy.market_bars
                   .where(
                     "recorded_at >= ?",
                     date.beginning_of_day
                   )
                   .order(:recorded_at)
                   .limit(11)
                   .to_a

        if bars.empty?
          empty_spy_returns
        else
          entry_price = bars.first.close.to_d

          {
            return_1d: forward_return(
              bars,
              entry_price,
              1
            ),
            return_3d: forward_return(
              bars,
              entry_price,
              3
            ),
            return_5d: forward_return(
              bars,
              entry_price,
              5
            ),
            return_10d: forward_return(
              bars,
              entry_price,
              10
            )
          }
        end
      end
    end

    def forward_return(bars, entry_price, days)
      return if entry_price.zero?

      bar = bars[days]

      return if bar.nil?

      (
        (bar.close.to_d - entry_price) /
        entry_price *
        100
      ).round(6)
    end

    def past_range(security, outcome)
      bars = security.market_bars
                    .where(
                      "recorded_at <= ?",
                      outcome.market_date.end_of_day
                    )
                    .order(recorded_at: :desc)
                    .limit(10)
                    .to_a

      return if bars.size < 10

      entry_price = outcome.price_at_signal.to_d

      return if entry_price.zero?

      high = bars.map(&:high).compact.max.to_d
      low = bars.map(&:low).compact.min.to_d

      (
        (high - low) /
        entry_price *
        100
      ).round(6)
    end

    def empty_spy_returns
      {
        return_1d: nil,
        return_3d: nil,
        return_5d: nil,
        return_10d: nil
      }
    end

    def headers
      [
        "symbol",
        "date",
        "mention_count",
        "submission_count",
        "comment_count",
        "unique_author_count",
        "total_score",
        "average_score",
        "market_date",
        "price_at_signal",
        "return_1d",
        "return_3d",
        "return_5d",
        "return_10d",
        "spy_return_1d",
        "spy_return_3d",
        "spy_return_5d",
        "spy_return_10d",
        "past_range_10d",
        "max_gain_10d",
        "max_drawdown_10d"
      ]
    end
  end
end