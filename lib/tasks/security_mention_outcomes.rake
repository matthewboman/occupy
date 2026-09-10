namespace :security_mention_outcomes do
  desc "Calculate market outcomes for security mentions"
  task calculate: :environment do
    before_count = SecurityMentionOutcome.count

    MarketData::CalculateAllSecurityMentionOutcomes.new.call

    created_count = (
      SecurityMentionOutcome.count -
      before_count
    )

    puts "Created #{created_count} outcomes"
    puts "Total outcomes: #{SecurityMentionOutcome.count}"
  end
end