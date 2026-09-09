class Security < ApplicationRecord
  has_many :market_bars,  dependent: :destroy
  has_many :social_posts, dependent: :destroy

  validates :symbol, presence: true, uniqueness: true

  before_validation :normalize_symbol

  def latest_market_bar
    market_bars.order(recorded_at: :desc).first
  end

  def return_for_days(days)
    bars = market_bars
             .order(recorded_at: :desc)
             .limit(days + 1)
             .to_a

    return if bars.length < days + 1

    latest_close = bars.first.close.to_d
    previous_close = bars.last.close.to_d

    ((latest_close - previous_close) / previous_close * 100).to_f
  end

  def volume_change
    bars = market_bars
             .order(recorded_at: :desc)
             .limit(2)
             .to_a

    return if bars.length < 2

    latest_volume = bars.first.volume.to_d
    previous_volume = bars.last.volume.to_d

    return if previous_volume.zero?

    ((latest_volume - previous_volume) / previous_volume * 100).to_f
  end

  private

  def normalize_symbol
    self.symbol = symbol.to_s.strip.upcase
  end
end