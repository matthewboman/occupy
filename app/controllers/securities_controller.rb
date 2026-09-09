class SecuritiesController < ApplicationController
  def show
    @security = Security.find(params[:id])

    @market_bars = @security.market_bars
                            .order(recorded_at: :desc)

    @one_day_return  = @security.return_for_days(1)
    @five_day_return = @security.return_for_days(5)
    @volume_change   = @security.volume_change
  end
end