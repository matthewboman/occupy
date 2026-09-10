namespace :market_data do
  desc "Backfill market history for securities mentioned in social data"
  task backfill_mentioned: :environment do
    MarketData::BackfillMentionedSecurities.new.call
  end
end