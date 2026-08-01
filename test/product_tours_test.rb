# frozen_string_literal: true

require 'test_helper'

class ProductToursTest < ActiveSupport::TestCase
  test 'has safe configuration defaults' do
    request = ActionDispatch::TestRequest.create

    assert ProductTours.enabled?(request)
    refute ProductTours.admin?(request)
    assert_equal '/product_tours', ProductTours.config.mount_path
    assert_equal '/product_tours/widget', ProductTours.config.widget_endpoint
    assert ProductTours.config.raise_on_unresolved_trigger.call(request)
  end

  test 'exposes loose user and tenant context' do
    request = ActionDispatch::TestRequest.create
    ProductTours.config.current_user = ->(_request) { fake_user }
    ProductTours.config.tenant = ->(_request) { 91 }

    assert_equal({ user_id: '42', user_label: 'Ada Lovelace' }, ProductTours.user_payload(request))
    assert_equal '91', ProductTours.tenant(request)
  end
end
