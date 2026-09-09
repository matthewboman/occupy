class DashboardController < ApplicationController
  def index
    @securities = Security.order(:symbol)
  end
end
