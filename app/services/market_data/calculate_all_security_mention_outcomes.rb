module MarketData
  class CalculateAllSecurityMentionOutcomes
    def call
      SecurityMention
        .where.missing(:security_mention_outcome)
        .find_each do |security_mention|

        CalculateSecurityMentionOutcome.new(
          security_mention: security_mention
        ).call
      rescue => error
        Rails.logger.error(
          "Outcome calculation failed for " \
          "SecurityMention #{security_mention.id}: " \
          "#{error.message}"
        )
      end
    end
  end
end