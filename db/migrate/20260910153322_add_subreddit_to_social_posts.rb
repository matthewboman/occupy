class AddSubredditToSocialPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :social_posts, :subreddit, :string
    add_index :social_posts, :subreddit
  end
end