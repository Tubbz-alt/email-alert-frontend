RSpec.describe SubscriptionsManagementController do
  include GdsApi::TestHelpers::EmailAlertApi
  include SessionHelper

  let(:subscriber_id) { 1 }
  let(:subscriber_address) { "test@example.com" }
  let(:subscription_id) { SecureRandom.uuid }
  let(:endpoint) { GdsApi::TestHelpers::EmailAlertApi::EMAIL_ALERT_API_ENDPOINT }
  let(:new_frequency) { "weekly" }
  let(:new_address) { "test2@example.com" }
  let(:session) { session_for(subscriber_id) }

  render_views

  before do
    stub_email_alert_api_has_subscriber_subscriptions(
      subscriber_id,
      subscriber_address,
      subscriptions: [
        {
          "id" => subscription_id,
          "created_at" => "2019-09-16 02:08:08 01:00",
          "subscriber_list" => { "title" => "Some thing" },
        },
      ],
    )

    stub_email_alert_api_has_updated_subscription(subscription_id, "weekly")
    stub_email_alert_api_has_updated_subscriber(subscriber_id, subscriber_address)
    stub_email_alert_api_unsubscribes_a_subscriber(subscriber_id)
  end

  describe "GET /email/manage" do
    context "when the page is requested" do
      it "returns 200" do
        get :index, session: session
        expect(response).to have_http_status(:ok)
      end
    end

    context "when there is a subscriber with a subscription" do
      it "renders the subscriber's email address" do
        get :index, session: session
        expect(response.body).to include("Subscriptions for #{subscriber_address}")
      end

      it "renders the subscriber's subscriptions" do
        get :index, session: session
        expect(response.body).to include("Some thing")
        expect(response.body).to include("Created on 16 September 2019 at 2:08am")
      end
    end

    context "when the subscription is for a brexit checker list" do
      before do
        stub_email_alert_api_has_subscriber_subscriptions(
          subscriber_id,
          subscriber_address,
          subscriptions: [
            {
              "id" => subscription_id,
              "created_at" => "2019-09-16 02:08:08 01:00",
              "subscriber_list" => {
                "title" => "Some thing",
                "url" => "/transition-check/results?c%5B%5D=automotive",
              },
            },
          ],
        )
      end

      it "renders a link to the list URL" do
        get :index, session: session
        expect(response.body).to include(
          "href=\"/transition-check/results?c%5B%5D=automotive\">You can view a copy of your results on GOV.UK</a>",
        )
      end
    end

    context "when there is a subscriber without any subscription" do
      let(:subscriber_id_with_no_subscriptions) { 2 }
      let(:subscriber_address_with_no_subscriptions) { "nothing@example.com" }
      let(:session_with_no_subscriptions) { session_for(subscriber_id_with_no_subscriptions) }

      before do
        stub_email_alert_api_has_subscriber_subscriptions(
          subscriber_id_with_no_subscriptions,
          subscriber_address_with_no_subscriptions,
          subscriptions: [],
        )
      end

      it "renders the subscriber's email address" do
        get :index, session: session_with_no_subscriptions
        expect(response.body).to include("Subscriptions for #{subscriber_address_with_no_subscriptions}")
      end

      it "renders a message" do
        get :index, session: session_with_no_subscriptions
        expect(response.body).to include("You aren’t subscribed to any topics on GOV.UK.")
      end
    end
  end

  describe "GET /email/manage/frequency/:id" do
    it "returns a 200 response" do
      get :update_frequency, params: { id: subscription_id }, session: session
      expect(response).to have_http_status(:ok)
    end

    it "renders a form" do
      get :update_frequency, params: { id: subscription_id }, session: session
      expect(response.body).to include(%(action="/email/manage/frequency/#{subscription_id}/change"))
    end

    it "returns 404 when the subscription doesn't belong to the subscriber" do
      stub_email_alert_api_has_subscriber_subscriptions(
        subscriber_id,
        subscriber_address,
        subscriptions: [],
      )

      get :update_frequency, params: { id: subscription_id }, session: session
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /email/manage/frequency/:id/change" do
    it "redirects to the subscription management page when frequency is updated" do
      post :change_frequency, params: { id: subscription_id, new_frequency: new_frequency }, session: session
      expect(response).to redirect_to(list_subscriptions_path)
    end

    it "raises an ActionController::ParameterMissing error when frequency is not provided" do
      expect {
        post :change_frequency, params: { id: subscription_id }, session: session
      }.to raise_error(ActionController::ParameterMissing)
    end

    it "returns a 400 response when an invalid frequency is provided" do
      stub_request(:patch, "#{endpoint}/subscriptions/#{subscription_id}")
        .to_return(status: 422)

      post :change_frequency,
           params: { id: subscription_id, new_frequency: "foobar" },
           session: session
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 404 when the subscription doesn't belong to the subscriber" do
      stub_email_alert_api_has_subscriber_subscriptions(
        subscriber_id,
        subscriber_address,
        subscriptions: [],
      )

      post :change_frequency,
           params: { id: subscription_id, new_frequency: new_frequency },
           session: session
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /email/manage/address" do
    context "when the page is requested" do
      it "returns 200" do
        get :update_address, session: session
        expect(response).to have_http_status(:ok)
      end

      it "renders a form" do
        get :update_address, session: session
        expect(response.body).to include(%(action="/email/manage/address/change"))
      end
    end
  end

  describe "POST /email/manage/address/change" do
    context "when no email address is provided" do
      let(:new_address) { "" }

      it "renders an error message" do
        post :change_address, params: { new_address: new_address }, session: session
        expect(response.body).to include(
          I18n.t!("subscriptions_management.update_address.missing_email"),
        )
      end

      it "renders a form" do
        post :change_address, params: { new_address: new_address }, session: session
        expect(response.body).to include(%(action="/email/manage/address/change"))
      end
    end

    context "when an invalid address is provided" do
      let(:new_address) { "foobar" }

      before do
        stub_email_alert_api_invalid_update_subscriber(subscriber_id)
      end

      it "renders an error message" do
        post :change_address, params: { new_address: new_address }, session: session
        expect(response.body).to include(
          I18n.t!("subscriptions_management.update_address.invalid_email"),
        )
      end

      it "renders a form" do
        post :change_address, params: { new_address: new_address }, session: session
        expect(response.body).to include(%(action="/email/manage/address/change"))
      end
    end

    context "when a valid address is provided" do
      it "redirects to the subscription management page" do
        post :change_address, params: { new_address: new_address }, session: session
        expect(response).to redirect_to(list_subscriptions_path)
      end
    end
  end

  describe "GET /email/manage/unsubscribe-all" do
    context "when the page is requested" do
      it "returns 200" do
        get :confirm_unsubscribe_all, session: session
        expect(response).to have_http_status(:ok)
      end

      it "renders a message" do
        get :confirm_unsubscribe_all, session: session
        expect(response.body).to include(
          I18n.t!("subscriptions_management.confirm_unsubscribe_all.description"),
        )
      end
    end

    it "renders a form" do
      get :confirm_unsubscribe_all, session: session
      expect(response.body).to include(%(action="/email/manage/unsubscribe-all"))
    end
  end

  describe "POST /email/manage/unsubscribe-all" do
    context "when the subscriber is unsubscribed" do
      it "redirects to subscription management" do
        post :confirmed_unsubscribe_all, session: session
        expect(response).to redirect_to(list_subscriptions_path)
      end

      it "sets a flash about the success" do
        post :confirmed_unsubscribe_all, session: session
        expect(flash[:success][:message]).to match(/unsubscribed from all your subscriptions/)
        expect(flash[:success][:description]).to match(/It can take up to an hour for this change to take effect./)
      end
    end
  end
end
