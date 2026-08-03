# frozen_string_literal: true

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

    def current_product_tours_locale
      requested_locale = params[:locale].to_s
      return requested_locale if I18n.available_locales.map(&:to_s).include?(requested_locale)

      ProductTours.locale(request)
    end

    def find_post_by_locale(scope, key)
      locales = [current_product_tours_locale, I18n.default_locale.to_s].uniq
      posts = scope.where(locale: locales, key: key).index_by(&:locale)
      locales.filter_map { |locale| posts[locale] }.first
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
      {
        key: key.to_s,
        locale: current_product_tours_locale,
        reason: reason.to_s,
        page_url: clean_page_url(params[:page_url])
      }
    end

    def handle_unresolved_trigger(key, reason)
      payload = unresolved_payload(key, reason)
      error = ProductTours::UnresolvedTriggerError.new(payload)
      raise error if Rails.env.development? || Rails.env.test?

      if defined?(Rails.error) && Rails.error.respond_to?(:report)
        Rails.error.report(error, handled: true, context: payload)
      else
        Rails.logger.error("product_tours: #{error.message} #{payload.inspect}")
      end
      ActiveSupport::Notifications.instrument('product_tours.unresolved_trigger', payload)
      render json: { error: 'unresolved_trigger', reason: reason.to_s }, status: :not_found
    end
  end
end
