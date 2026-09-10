require "csv"

namespace :historical_reddit do
  desc "Import a normalized historical Reddit CSV file"
  task import: :environment do
    path = ENV["FILE"]

    if path.blank?
      raise <<~ERROR
        FILE is required.

        Example:
        bin/rails historical_reddit:import FILE=data/reddit/normalized/reddit_archive.csv
      ERROR
    end

    full_path = Rails.root.join(path)

    external_ids = CSV.read(
      full_path,
      headers: true
    ).map { |row| row["external_id"] }

    SocialData::ImportHistoricalReddit.new(
      path: full_path
    ).call

    posts = SocialPost.where(
      source:      "reddit",
      external_id: external_ids
    )

    with_mentions = posts
      .joins(:security_mentions)
      .distinct

    securities = Security
      .joins(:security_mentions)
      .where(
        security_mentions: {
          social_post_id: posts.select(:id)
        }
      )
      .distinct

    puts "Imported #{path}"
    puts "Records: #{posts.count}"
    puts "Submissions: #{posts.submissions.count}"
    puts "Comments: #{posts.comments.count}"
    puts "With security mentions: #{with_mentions.count}"
    puts "Without security mentions: #{posts.where.missing(:security_mentions).count}"
    puts "Unique securities mentioned: #{securities.count}"
  end
end