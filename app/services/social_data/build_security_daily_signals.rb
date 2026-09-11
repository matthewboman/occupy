module SocialData
  class BuildSecurityDailySignals
    def call
      rows = aggregated_rows

      return if rows.empty?

      now        = Time.current
      attributes = rows.map do |row|
        {
          security_id:         row.security_id,
          date:                row.date,
          mention_count:       row.mention_count,
          submission_count:    row.submission_count,
          comment_count:       row.comment_count,
          unique_author_count: row.unique_author_count,
          total_score:         row.total_score,
          average_score:       row.average_score,
          created_at:          now,
          updated_at:          now
        }
      end

      SecurityDailySignal.upsert_all(
        attributes,
        unique_by: [:security_id, :date],
        update_only: [
          :mention_count,
          :submission_count,
          :comment_count,
          :unique_author_count,
          :total_score,
          :average_score
        ]
      )
    end

    private

    def aggregated_rows
      SecurityMention
        .joins(:social_post)
        .select(
          "security_mentions.security_id",
          "DATE(social_posts.posted_at) AS date",
          "COUNT(*) AS mention_count",
          "COUNT(*) FILTER (WHERE social_posts.record_type = 'submission') AS submission_count",
          "COUNT(*) FILTER (WHERE social_posts.record_type = 'comment') AS comment_count",
          "COUNT(DISTINCT social_posts.author) AS unique_author_count",
          "COALESCE(SUM(social_posts.score), 0) AS total_score",
          "AVG(social_posts.score) AS average_score"
        )
        .group(
          "security_mentions.security_id",
          "DATE(social_posts.posted_at)"
        )
    end
  end
end