# frozen_string_literal: true

require 'test_helper'
require 'open3'

class ProductToursTest < ActiveSupport::TestCase
  test 'top-level require loads Rails before the engine' do
    command = <<~RUBY
      abort 'Rails was already loaded' if defined?(Rails)
      require 'product_tours'
      print ProductTours::VERSION
    RUBY
    lib_path = ProductTours::Engine.root.join('lib').to_s
    output, error, status = Open3.capture3(RbConfig.ruby, "-I#{lib_path}", '-e', command)

    assert status.success?, error
    assert_equal ProductTours::VERSION, output
  end

  test 'has safe configuration defaults' do
    request = ActionDispatch::TestRequest.create

    assert ProductTours.enabled?(request)
    refute ProductTours.admin?(request)
    assert_equal '/product_tours', ProductTours.config.mount_path
    assert_equal '/product_tours/widget', ProductTours.config.widget_endpoint
    assert_equal I18n.locale.to_s, ProductTours.locale(request)
    assert_nothing_raised do
      ProductTours.config.on_event.call('product_tours.viewed', { key: 'welcome' }, request)
    end
  end

  test 'uses the current locale without identity, tenant, or rate configuration' do
    request = ActionDispatch::TestRequest.create

    I18n.with_locale(:fr) { assert_equal 'fr', ProductTours.locale(request) }
    refute_respond_to ProductTours.config, :current_user
    refute_respond_to ProductTours.config, :user_label
    refute_respond_to ProductTours.config, :tenant
    refute_respond_to ProductTours.config, :locale
    refute_respond_to ProductTours.config, :rate_limit
    refute_respond_to ProductTours.config, :raise_on_unresolved_trigger
  end
end
