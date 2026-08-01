# frozen_string_literal: true

require 'product_tours/version'
require 'product_tours/configuration'
require 'product_tours/errors'
require 'product_tours/video_resolver'
require 'product_tours/video_metadata'
require 'product_tours/widget'
require 'product_tours/seeds'
require 'product_tours/engine'

module ProductTours
  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end

    def enabled?(request)
      !!config.enabled.call(request)
    end

    def admin?(request)
      !!config.authorize_admin.call(request)
    end

    def tenant(request)
      config.tenant.call(request).presence&.to_s
    end

    def locale(request)
      config.locale.call(request).presence&.to_s || I18n.default_locale.to_s
    end

    def user_payload(request)
      user = config.current_user.call(request)
      return { user_id: nil, user_label: nil } if user.nil?

      {
        user_id: user.respond_to?(:id) ? user.id.to_s : nil,
        user_label: config.user_label.call(user).presence&.to_s
      }
    end
  end
end
