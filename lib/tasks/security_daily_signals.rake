namespace :security_daily_signals do
  desc "Build daily Reddit signal aggregates by security"
  task build: :environment do
    before_count = SecurityDailySignal.count

    SocialData::BuildSecurityDailySignals.new.call

    created_count = SecurityDailySignal.count - before_count

    puts "Created #{created_count} daily signals"
    puts "Total daily signals: #{SecurityDailySignal.count}"
  end
end