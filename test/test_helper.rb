# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'

require_relative 'dummy/config/environment'
require 'rails/test_help'
require 'rack/test'

require_relative 'support/schema'

module ActiveSupport
  class TestCase
    self.use_transactional_tests = true

    setup do
      ProductTours.instance_variable_set(:@config, ProductTours::Configuration.new)
      Rails.cache.clear
    end

    teardown do
      ProductTours.instance_variable_set(:@config, nil)
    end

    private

    def as_admin!
      ProductTours.config.authorize_admin = ->(_request) { true }
    end

    def create_tour(**attributes)
      defaults = { key: 'billing_setup', locale: 'en', title: 'Set up billing', status: 'published' }
      ProductTours::Tour.create!(defaults.merge(attributes))
    end

    def fake_video(name: 'tutorial.webm', content: 'fake video bytes', type: 'video/webm')
      Rack::Test::UploadedFile.new(StringIO.new(content), type, original_filename: name)
    end
  end
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1200, 900]
end
