require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should create session with valid credentials" do
    user = users(:one)

    post "/sessions", params: {
      user: {
        email: user.email,
        password: "password123"
      }
    }

    assert_response :success
  end

  test "should destroy session" do
    delete "/logout"
    assert_response :success
  end

  test "should get logged_in status" do
    get "/logged_in"
    assert_response :success
  end
end