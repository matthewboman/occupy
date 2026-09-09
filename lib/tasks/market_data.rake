namespace :market_data do
  desc "Import daily market bars for active securities"
  task import_daily: :environment do
    Security.where(is_active: true).find_each do |security|
      puts "Importing #{security.symbol}"

      MarketData::ImportDailyBars.new(
        security: security
      ).call
    end
  end
end