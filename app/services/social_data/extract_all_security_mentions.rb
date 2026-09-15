module SocialData
  class ExtractAllSecurityMentions
    EXTRACTION_VERSION = 2

    def call
      security_name_index = SocialData::SecurityNameIndex.new

      SocialPost
        .where(
          "security_mentions_version IS NULL OR security_mentions_version < ?",
          EXTRACTION_VERSION
        )
        .find_each do |social_post|

        puts social_post.id

        ExtractSecurityMentions.new(
          social_post: social_post,
          security_name_index: security_name_index
        ).call

        social_post.update_column(
          :security_mentions_version,
          EXTRACTION_VERSION
        )
      end
    end
  end
end