class SubscriptionsManagementController < ApplicationController
  before_action :require_authentication
  before_action :get_subscription_details
  before_action :set_back_url

  def index; end

  def update_frequency
    @subscription_id = params.require(:id)
    return error_not_found unless @subscriptions[@subscription_id]

    @current_frequency = @subscriptions[@subscription_id]["frequency"]
  end

  def change_frequency
    id = params.require(:id)
    return error_not_found unless @subscriptions[id]

    new_frequency = params.require(:new_frequency)

    GdsApi.email_alert_api.change_subscription(id: id, frequency: new_frequency)

    subscription_title = @subscriptions[id]["subscriber_list"]["title"]

    frequency_text = if new_frequency == "immediately"
                       I18n.t!("frequencies.immediately").downcase
                     else
                       new_frequency
                     end

    flash[:success] = {
      message: t("subscriptions_management.change_frequency.success", subscription_title: subscription_title, frequency: frequency_text),
    }

    redirect_to list_subscriptions_path
  end

  def update_address
    @address = @subscriber["address"]
  end

  def change_address
    @address = @subscriber["address"]

    if params[:new_address].blank?
      flash.now[:error] = t("subscriptions_management.update_address.missing_email")
      return render :update_address
    end

    new_address = params.require(:new_address)

    GdsApi.email_alert_api.change_subscriber(
      id: authenticated_subscriber_id,
      new_address: new_address,
    )
    flash[:success] = {
      message: t("subscriptions_management.update_address.success", address: new_address),
    }

    redirect_to list_subscriptions_path
  rescue GdsApi::HTTPUnprocessableEntity
    @new_address = new_address
    flash.now[:error] = t("subscriptions_management.update_address.invalid_email")
    render :update_address
  end

  def confirm_unsubscribe_all; end

  def confirmed_unsubscribe_all
    begin
      GdsApi.email_alert_api.unsubscribe_subscriber(authenticated_subscriber_id)
      flash[:success] = {
        message: t("subscriptions_management.confirmed_unsubscribe_all.success_message"),
        description: t("subscriptions_management.confirmed_unsubscribe_all.success_description"),
      }
    rescue GdsApi::HTTPNotFound
      # The user has already unsubscribed.
      nil
    end
    redirect_to list_subscriptions_path
  end

private

  def get_subscription_details
    subscription_details = GdsApi.email_alert_api.get_subscriptions(
      id: authenticated_subscriber_id,
    )

    @subscriber = subscription_details["subscriber"]
    @subscriptions = {}

    subscription_details["subscriptions"].each do |subscription|
      @subscriptions[subscription["id"]] = subscription
    end
  end

  def set_back_url
    @back_url = list_subscriptions_path
  end
end
