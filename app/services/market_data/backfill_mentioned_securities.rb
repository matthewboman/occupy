require "json"

module MarketData
  class BackfillMentionedSecurities
    START_DATE = Date.new(2023, 12, 1)
    REQUEST_DELAY = 13
    MIN_MENTIONS = 5

    DEFAULT_STATE_PATH = Rails.root.join(
      "data",
      "market_data",
      "backfill_state.json"
    )

    def initialize(
      client: StashGammaClient.new,
      start_date: START_DATE,
      end_date: Date.current,
      request_delay: REQUEST_DELAY,
      state_path: DEFAULT_STATE_PATH,
      min_mentions: MIN_MENTIONS
    )
      @client = client
      @start_date = start_date
      @end_date = end_date
      @request_delay = request_delay
      @state_path = Pathname.new(state_path)
      @min_mentions = min_mentions
      @state = load_state
    end

    def call
      securities = mentioned_securities.to_a

      puts "Mentioned securities: #{securities.count}"
      puts "Unavailable: #{unavailable_symbols.count}"
      puts "Backfill through: #{@end_date}"

      securities.each_with_index do |security, index|
        if unavailable?(security)
          puts "Skipping unavailable #{security.symbol}"
          next
        end

        security_start_date = next_start_date(security)

        if security_start_date > @end_date
          puts "Already current #{security.symbol}"
          next
        end

        puts(
          "Backfilling #{security.symbol}: " \
          "#{security_start_date} through #{@end_date}"
        )

        begin
          backfill_security(
            security,
            security_start_date
          )

          puts "Completed #{security.symbol}"
        rescue StashGammaClient::Error => error
          if error.status_code == 404
            mark_unavailable(security)

            puts "Unavailable #{security.symbol}: #{error.message}"
          elsif error.status_code == 429
            puts "Rate limit reached: #{error.message}"
            puts "Stopping backfill."

            raise
          else
            puts "Failed #{security.symbol}: #{error.message}"
          end
        rescue => error
          puts "Failed #{security.symbol}: #{error.message}"
        end

        sleep_between_requests(
          securities,
          index
        )
      end

      puts
      puts "Backfill finished"
      puts "Unavailable symbols: #{unavailable_symbols.count}"
    end

    private

    def mentioned_securities
      Security
        .joins(:security_mentions)
        .group("securities.id")
        .having(
          "COUNT(DISTINCT security_mentions.social_post_id) >= ?",
          @min_mentions
        )
        .order(:symbol)
    end

    def next_start_date(security)
      latest_recorded_at = security.market_bars.maximum(
        :recorded_at
      )

      return @start_date if latest_recorded_at.blank?

      [
        latest_recorded_at.to_date + 1.day,
        @start_date
      ].max
    end

    def backfill_security(
      security,
      start_date
    )
      ImportDailyBars.new(
        security: security,
        client: @client,
        start_date: start_date,
        end_date: @end_date
      ).call
    end

    def unavailable?(security)
      unavailable_symbols.include?(
        security.symbol
      )
    end

    def unavailable_symbols
      @state["unavailable_symbols"] ||= []
    end

    def mark_unavailable(security)
      unavailable_symbols << security.symbol
      unavailable_symbols.uniq!

      save_state
    end

    def load_state
      return default_state unless @state_path.exist?

      state = JSON.parse(
        @state_path.read
      )

      {
        "unavailable_symbols" => state.fetch(
          "unavailable_symbols",
          []
        )
      }
    end

    def default_state
      {
        "unavailable_symbols" => []
      }
    end

    def save_state
      @state_path.dirname.mkpath

      @state_path.write(
        JSON.pretty_generate(
          @state
        )
      )
    end

    def sleep_between_requests(
      securities,
      index
    )
      return if @request_delay.zero?
      return if index == securities.length - 1

      sleep(
        @request_delay
      )
    end
  end
end