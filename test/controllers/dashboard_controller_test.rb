require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "shows securities" do
    get root_path

    assert_response :success
    assert_select "a", text: "NVDA"
    assert_select "a", text: "GME"
  end

  test "security symbols link to security pages" do
    security = securities(:nvda)

    get root_path

    assert_select "a[href='#{security_path(security)}']", text: "NVDA"
  end
end