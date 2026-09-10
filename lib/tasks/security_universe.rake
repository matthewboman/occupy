namespace :security_universe do
  desc "Import current US-listed securities"
  task import: :environment do
    MarketData::ImportSecurityUniverse.new.call

    puts "Imported #{Security.count} securities"
  end
end