namespace :security_daily_outcomes do
  desc "Calculate forward market outcomes for daily security signals"
  task calculate: :environment do
    before_count = SecurityDailyOutcome.count

    MarketData::CalculateAllSecurityDailyOutcomes.new.call

    created_count = (
      SecurityDailyOutcome.count -
      before_count
    )

    puts "Created #{created_count} daily outcomes"
    puts "Total daily outcomes: #{SecurityDailyOutcome.count}"
  end
end