# frozen_string_literal: true

require 'product_tours/version'
require 'product_tours/configuration'
require 'product_tours/errors'
require 'product_tours/video_resolver'
require 'product_tours/video_metadata'
require 'product_tours/content_security_policy'
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

    def locale(_request = nil)
      I18n.locale.to_s.presence || I18n.default_locale.to_s
    end
  end
end
