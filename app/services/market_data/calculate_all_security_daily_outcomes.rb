module MarketData
  class CalculateAllSecurityDailyOutcomes
    def call
      SecurityDailySignal.find_each do |signal|
        CalculateSecurityDailyOutcome.new(
          security_daily_signal: signal
        ).call
      rescue => error
        Rails.logger.error(
          "Daily outcome calculation failed for " \
          "SecurityDailySignal #{signal.id}: " \
          "#{error.message}"
        )
      end
    end
  end
end