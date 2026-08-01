# frozen_string_literal: true

require 'securerandom'
require 'uri'

module ProductTours
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    private

    def product_tours_admin_layout
      ProductTours.config.admin_layout
    end

    def require_admin
      return if ProductTours.admin?(request)

      render plain: 'Forbidden. Set ProductTours.config.authorize_admin to grant access.', status: :forbidden
    end

    def current_product_tours_user
      return @current_product_tours_user if defined?(@current_product_tours_user)

      @current_product_tours_user = ProductTours.config.current_user.call(request)
    end

    def user_context
      user = current_product_tours_user
      {
        user_id: user.respond_to?(:id) ? user.id.to_s : nil,
        user_label: user ? ProductTours.config.user_label.call(user).presence&.to_s : nil
      }
    end

    def current_product_tours_locale
      ProductTours.locale(request)
    end

    def current_product_tours_tenant
      ProductTours.tenant(request)
    end

    def ensure_visitor_token
      return if current_product_tours_user

      cookies[:product_tours_vid].presence || begin
        token = SecureRandom.base58(24)
        cookies.permanent[:product_tours_vid] = { value: token, httponly: true, same_site: :lax }
        token
      end
    end

    def clean_page_url(value)
      uri = URI.parse(value.to_s)
      return unless uri.is_a?(URI::HTTP) && uri.host.present?

      uri.query = nil
      uri.fragment = nil
      uri.to_s
    rescue URI::InvalidURIError
      nil
    end

    def unresolved_payload(key, reason)
      user_context.merge(
        key: key.to_s,
        locale: current_product_tours_locale,
        reason: reason.to_s,
        page_url: clean_page_url(params[:page_url]),
        tenant: current_product_tours_tenant,
        visitor_token: ensure_visitor_token
      )
    end

    def handle_unresolved_trigger(key, reason)
      payload = unresolved_payload(key, reason)
      error = ProductTours::UnresolvedTriggerError.new(payload)
      raise error if ProductTours.config.raise_on_unresolved_trigger.call(request)

      if defined?(Rails.error) && Rails.error.respond_to?(:report)
        Rails.error.report(error, handled: true, context: payload)
      else
        Rails.logger.error("product_tours: #{error.message} #{payload.inspect}")
      end
      ActiveSupport::Notifications.instrument('product_tours.unresolved_trigger', payload)
      render json: { error: 'unresolved_trigger', reason: reason.to_s }, status: :not_found
    end

    def render_rate_limited
      render json: { error: 'rate_limited' }, status: :too_many_requests
    end
  end
end
