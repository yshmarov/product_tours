# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "active_storage/engine"
require "action_text/engine"
require "product_tours"

module Dummy
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.load_defaults 7.1
    config.eager_load = false
    config.active_record.maintain_test_schema = false
    config.secret_key_base = "product-tours-dummy-secret"
    config.i18n.available_locales = %i[en fr ar]
    config.i18n.default_locale = :en

    config.content_security_policy do |policy|
      policy.script_src :self
      policy.frame_src :self
    end
    config.content_security_policy_nonce_generator = ->(_request) { "testnonce" }
    config.content_security_policy_nonce_directives = %w[script-src]
  end
end
