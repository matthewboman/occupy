namespace :security_mentions do
  desc "Extract known security symbols from social posts"
  task extract: :environment do
    before_count = SecurityMention.count

    SocialData::ExtractAllSecurityMentions.new.call

    created_count = SecurityMention.count - before_count

    puts "Created #{created_count} security mentions"
    puts "Total security mentions: #{SecurityMention.count}"
    puts "Posts with securities: #{SocialPost.with_security_mentions.count}"
    puts "Posts without securities: #{SocialPost.without_security_mentions.count}"
  end
end