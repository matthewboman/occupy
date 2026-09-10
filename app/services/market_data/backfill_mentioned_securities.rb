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
      request_delay: REQUEST_DELAY,
      state_path: DEFAULT_STATE_PATH,
      min_mentions: MIN_MENTIONS
    )
      @client = client
      @start_date = start_date
      @request_delay = request_delay
      @state_path = Pathname.new(state_path)
      @min_mentions = min_mentions
      @state = load_state
    end

    def call
      securities = mentioned_securities.to_a

      puts "Mentioned securities: #{securities.count}"
      puts "Already completed: #{completed_symbols.count}"
      puts "Unavailable: #{unavailable_symbols.count}"

      securities.each_with_index do |security, index|
        if completed?(security)
          puts "Skipping completed #{security.symbol}"
          next
        end

        if unavailable?(security)
          puts "Skipping unavailable #{security.symbol}"
          next
        end

        puts "Backfilling #{security.symbol}"

        begin
          backfill_security(security)

          mark_completed(security)

          puts "Completed #{security.symbol}"
        rescue StashGammaClient::Error => error
          if error.status_code == 404
            mark_unavailable(security)

            puts "Unavailable #{security.symbol}: #{error.message}"
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
      puts "Completed symbols: #{completed_symbols.count}"
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
    end

    def backfill_security(security)
      ImportDailyBars.new(
        security: security,
        client: @client,
        start_date: @start_date
      ).call
    end

    def completed?(security)
      completed_symbols.include?(
        security.symbol
      )
    end

    def unavailable?(security)
      unavailable_symbols.include?(
        security.symbol
      )
    end

    def completed_symbols
      @state["completed_symbols"] ||= []
    end

    def unavailable_symbols
      @state["unavailable_symbols"] ||= []
    end

    def mark_completed(security)
      completed_symbols << security.symbol
      completed_symbols.uniq!

      save_state
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

      state["completed_symbols"] ||= []
      state["unavailable_symbols"] ||= []

      state
    end

    def default_state
      {
        "completed_symbols" => [],
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