module SocialData
  class ExtractSecurityMentions
    TOKEN_PATTERN = /(?<![A-Za-z0-9])\$?[A-Z]{1,5}(?![A-Za-z0-9])/

    AMBIGUOUS_BARE_SYMBOLS = %w[
      A
      AI
      ALL
      AM
      ARE
      B
      BE
      BTC
      C
      D
      DD
      E
      EOD
      EPS
      ETH
      EU
      F
      FOR
      G
      GO
      HODL
      IPO
      IT
      ITM
      J
      L
      LOVE
      M
      NOW
      O
      ON
      OR
      P
      PM
      R
      S
      T
      TLDR
      U
      UK
      UP
      USA
      USD
      V
      W
      WTF
      YOLO
      YOU
    ].freeze

    MATCH_PRIORITY = {
      "company_name" => 1,
      "ticker" => 2,
      "cashtag" => 3
    }.freeze

    def initialize(
      social_post:,
      security_name_index: SocialData::SecurityNameIndex.new
    )
      @social_post = social_post
      @security_name_index = security_name_index
    end

    def call
      matches.each_value do |match|
        mention = SecurityMention.find_or_initialize_by(
          social_post: @social_post,
          security: match[:security]
        )

        if mention.new_record? ||
           higher_priority?(match[:match_type], mention.match_type)

          mention.match_type = match[:match_type]
          mention.matched_text = match[:matched_text]
        end

        mention.save!
      end
    end

    private

    def matches
      @matches ||= begin
        found = {}

        ticker_matches.each do |match|
          add_match(found, match)
        end

        company_name_matches.each do |match|
          add_match(found, match)
        end

        found
      end
    end

    def ticker_matches
      tokens.filter_map do |token|
        prefixed = token.start_with?("$")
        symbol = token.delete_prefix("$")

        next if !prefixed && ambiguous_bare_symbol?(symbol)

        security = securities_by_symbol[symbol]

        next unless security

        {
          security: security,
          match_type: prefixed ? "cashtag" : "ticker",
          matched_text: token
        }
      end
    end

    def company_name_matches
      @security_name_index
        .matches(@social_post.body.to_s)
        .map do |match|

        {
          security: match[:security],
          match_type: "company_name",
          matched_text: match[:matched_text]
        }
      end
    end

    def add_match(found, match)
      security_id = match[:security].id
      existing = found[security_id]

      if existing.blank? ||
         higher_priority?(
           match[:match_type],
           existing[:match_type]
         )
        found[security_id] = match
      end
    end

    def higher_priority?(new_type, existing_type)
      return true if existing_type.blank?

      MATCH_PRIORITY.fetch(new_type) >
        MATCH_PRIORITY.fetch(existing_type, 0)
    end

    def tokens
      @social_post.body.to_s.scan(
        TOKEN_PATTERN
      )
    end

    def ambiguous_bare_symbol?(symbol)
      symbol.length == 1 ||
        AMBIGUOUS_BARE_SYMBOLS.include?(symbol)
    end

    def securities_by_symbol
      @securities_by_symbol ||= Security
        .where(symbol: ticker_symbols)
        .index_by(&:symbol)
    end

    def ticker_symbols
      @ticker_symbols ||= tokens.map {
        |token| token.delete_prefix("$")
      }.uniq
    end
  end
end