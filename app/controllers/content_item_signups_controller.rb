# This controller takes any content item and makes it possible to subscribe
# to alerts when documents linked to them are changed (taxons, orgs etc).
# This is in contrast to EmailAlertSignupsController, which takes a
# finder_email_signup content item.
class ContentItemSignupsController < ApplicationController
  include TaxonsHelper

  protect_from_forgery except: [:create]
  before_action :assign_content_item
  before_action :handle_redirects
  before_action :assign_list_params

  def new
    if is_taxon?(@content_item) && taxon_children(@content_item).any?
      render "taxon"
    else
      render "confirm"
    end
  end

  def confirm; end

  def create
    slug = GdsApi.email_alert_api
                 .find_or_create_subscriber_list(@list_params)
                 .dig("subscriber_list", "slug")

    redirect_to new_subscription_path(topic_id: slug)
  end

private

  def handle_redirects
    return unless @content_item["document_type"] == "redirect"

    destination_path = @content_item.dig("redirects", 0, "destination")
    return error_not_found if destination_path.nil?

    redirect_to(new_content_item_signup_path(topic: destination_path))
  end

  def assign_content_item
    # Topic param left in for backwards compatibility.
    # Topic is the user-facing terminology for taxons. Expect the taxon base
    # path to be provided in a param of this name.
    content_item_path = params[:link] || params[:topic]

    return bad_request unless content_item_path.to_s.starts_with?("/")
    return bad_request unless URI.parse(content_item_path).relative?

    @content_item ||= GdsApi.content_store.content_item(content_item_path)
  rescue URI::InvalidURIError
    bad_request
  end

  def assign_list_params
    @list_params = GenerateSubscriberListParamsService.call(@content_item.to_h)
  rescue GenerateSubscriberListParamsService::UnsupportedContentItemError
    bad_request
  end
end
