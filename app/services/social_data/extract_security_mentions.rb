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

    def initialize(social_post:)
      @social_post = social_post
    end

    def call
      symbols.each do |symbol|
        security = securities_by_symbol[symbol]

        next unless security

        SecurityMention.find_or_create_by!(
          social_post: @social_post,
          security: security
        )
      end
    end

    private

    def symbols
      @symbols ||= tokens.filter_map do |token|
        prefixed = token.start_with?("$")
        symbol = token.delete_prefix("$")

        next if !prefixed && ambiguous_bare_symbol?(symbol)

        symbol
      end.uniq
    end

    def tokens
      @social_post.body.scan(
        TOKEN_PATTERN
      )
    end

    def ambiguous_bare_symbol?(symbol)
      symbol.length == 1 ||
        AMBIGUOUS_BARE_SYMBOLS.include?(symbol)
    end

    def securities_by_symbol
      @securities_by_symbol ||= Security.where(
        symbol: symbols
      ).index_by(&:symbol)
    end
  end
end