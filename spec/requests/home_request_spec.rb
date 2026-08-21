require 'rails_helper'

RSpec.describe "Homes", type: :request do
  describe "GET /index" do
    context "when unauthenticated" do
      it "returns http success (home is public)" do
        get "/home/index"
        expect(response).to have_http_status(:success)
      end
    end

    context "when authenticated" do
      let(:user) { User.create!(email_address: "test@example.com", password: "password123!", role: :user) }

      before do
        post session_path, params: { email_address: user.email_address, password: "password123!" }
      end

      it "redirects to dashboard" do
        get "/home/index"
        expect(response).to redirect_to(dashboard_path)
      end
    end
  end
end
