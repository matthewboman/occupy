module SocialData
  class SecurityNameIndex
    COMPANY_SUFFIXES = [
      "Corporation",
      "Corp",
      "Incorporated",
      "Inc",
      "Limited",
      "Ltd",
      "PLC",
      "Holdings",
      "Holding",
      "Company",
      "Co"
    ].freeze

    AMBIGUOUS_COMPANY_NAMES = %w[
      Apple
      Gap
      Target
      Unity
    ].freeze

    def initialize
      @aliases_by_first_word = Hash.new {
        |hash, key| hash[key] = []
      }

      build_index
    end

    def matches(text)
      candidate_aliases(text).filter_map do |entry|
        matched = text.match(
          /(?<![A-Za-z0-9])#{Regexp.escape(entry[:alias])}(?![A-Za-z0-9])/i
        )

        next unless matched

        {
          security: entry[:security],
          matched_text: matched[0]
        }
      end
    end

    private

    def build_index
      Security
        .where(is_active: true)
        .where.not(name: [nil, ""])
        .find_each do |security|

        company_aliases(security).each do |company_alias|
          first_word = normalize_word(
            company_alias.split.first
          )

          @aliases_by_first_word[first_word] << {
            security: security,
            alias: company_alias
          }
        end
      end
    end

    def candidate_aliases(text)
      words = text
        .scan(/[A-Za-z0-9]+/)
        .map { |word| normalize_word(word) }
        .uniq

      words.flat_map {
        |word| @aliases_by_first_word[word]
      }.uniq
    end

    def company_aliases(security)
      name = security.name.strip

      [
        name,
        strip_company_suffixes(name)
      ].uniq.reject do |company_alias|
        company_alias.length < 4 ||
          ambiguous_company_name?(company_alias)
      end
    end

    def strip_company_suffixes(name)
      result = name.dup

      COMPANY_SUFFIXES.each do |suffix|
        result = result.sub(
          /[,\s]+#{Regexp.escape(suffix)}\.?\z/i,
          ""
        )
      end

      result.strip
    end

    def ambiguous_company_name?(name)
      AMBIGUOUS_COMPANY_NAMES.any? {
        |ambiguous| ambiguous.casecmp?(name)
      }
    end

    def normalize_word(word)
      word.to_s.downcase
    end
  end
end