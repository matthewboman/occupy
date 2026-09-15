class AddSecurityMentionsVersionToSocialPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :social_posts, :security_mentions_version, :integer
  end
end
