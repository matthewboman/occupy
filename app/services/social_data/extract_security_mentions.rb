module SocialData
  class ExtractSecurityMentions
    TOKEN_PATTERN = /(?<![A-Za-z0-9])\$?[A-Z]{1,5}(?![A-Za-z0-9])/

    def initialize(social_post:)
      @social_post = social_post
    end

    def call
      symbols.each do |symbol|
        security = securities_by_symbol[symbol]

        next unless security

        SecurityMention.find_or_create_by!(
          social_post: @social_post,
          security:    security
        )
      end
    end

    private

    def symbols
      @symbols ||= @social_post.body
                               .scan(TOKEN_PATTERN)
                               .map { |token| token.delete_prefix("$") }
                               .uniq
    end

    def securities_by_symbol
      @securities_by_symbol ||= Security.where(
        symbol: symbols
      ).index_by(&:symbol)
    end
  end
end