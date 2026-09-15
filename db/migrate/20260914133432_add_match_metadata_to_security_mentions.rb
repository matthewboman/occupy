class AddMatchMetadataToSecurityMentions < ActiveRecord::Migration[8.1]
  def change
    add_column :security_mentions, :match_type, :string
    add_column :security_mentions, :matched_text, :string
  end
end
