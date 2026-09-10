namespace :historical_reddit do
  desc "Import a normalized historical Reddit CSV file"
  task import: :environment do
    path = ENV["FILE"]

    if path.blank?
      raise <<~ERROR
        FILE is required.

        Example:
        bin/rails historical_reddit:import FILE=data/reddit/normalized/wallstreetbets_submissions_2023_12.csv
      ERROR
    end

    SocialData::ImportHistoricalReddit.new(
      path: Rails.root.join(path)
    ).call

    puts "Imported #{path}"
  end
end