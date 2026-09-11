namespace :analysis do
  desc "Export daily social signals and market outcomes"
  task export_daily_signals: :environment do
    path = Rails.root.join(
      "data",
      "analysis",
      "security_daily_dataset.csv"
    )

    Analysis::ExportSecurityDailyDataset.new(
      path: path
    ).call

    puts "Exported dataset to #{path}"
  end
end