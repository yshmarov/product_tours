# frozen_string_literal: true

require 'test_helper'

class WidgetTest < ActionDispatch::IntegrationTest
  test 'renders a nonce-aware same-origin widget tag' do
    get '/sample'

    assert_response :ok
    assert_includes response.body, 'data-product-tours-config'
    assert_includes response.body, '<script src="/product_tours/widget.js?v='
    assert_includes response.body, 'nonce="testnonce"'
    assert_includes response.body, 'data-product-tour="missing_demo"'
  end

  test 'renders no widget tag when disabled' do
    ProductTours.config.enabled = ->(_request) { false }
    get '/sample'

    refute_includes response.body, 'data-product-tours-config'
  end

  test 'serves fingerprinted widget and dashboard assets' do
    get '/product_tours/widget.js', params: { v: ProductTours::Widget.fingerprint }
    assert_response :ok
    assert_equal 'text/javascript', response.media_type
    assert_includes response.body, 'data-product-tour'
    assert_match(/max-age=315\d+/, response.headers['Cache-Control'])

    get '/product_tours/dashboard.css'
    assert_response :ok
    assert_equal 'text/css', response.media_type
  end

  test 'resolves a current-locale published post' do
    create_post(description: 'Configure a plan', action_label: 'Open billing', action_url: '/billing',
                video_url: 'https://vimeo.com/76979871')

    get '/product_tours/widget/post', params: { key: 'billing_setup', page_url: 'https://app.test/settings?token=secret' }

    assert_response :ok
    payload = response.parsed_body
    assert_equal 'Set up billing', payload['title']
    assert_includes payload['descriptionHtml'], 'Configure a plan'
    assert_equal 'iframe', payload.dig('video', 'kind')
    assert_equal '/billing', payload.dig('action', 'url')
  end

  test 'reports unresolved draft and missing triggers without opening' do
    report_unresolved!
    create_post(status: 'draft')
    events = []
    subscriber = ActiveSupport::Notifications.subscribe('product_tours.unresolved_trigger') do |*args|
      events << args.last
    end

    get '/product_tours/widget/post', params: { key: 'billing_setup', page_url: 'https://app.test/path?secret=1' }
    assert_response :not_found
    assert_equal 'unpublished', events.last[:reason]
    assert_equal 'https://app.test/path', events.last[:page_url]

    get '/product_tours/widget/post', params: { key: 'missing' }
    assert_response :not_found
    assert_equal 'missing', events.last[:reason]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test 'raises unresolved triggers by default in test' do
    assert_raises(ProductTours::UnresolvedTriggerError) do
      get '/product_tours/widget/post', params: { key: 'Bad key' }
    end
  end

  test 'emits meaningful lifecycle signals with host context' do
    create_post
    ProductTours.config.current_user = ->(_request) { fake_user }
    ProductTours.config.tenant = ->(_request) { 'gid://dummy/Organization/7' }
    payloads = []
    subscriber = ActiveSupport::Notifications.subscribe('product_tours.completed') do |*args|
      payloads << args.last
    end

    post '/product_tours/widget/signal', params: {
      key: 'billing_setup', event_action: 'completed', source: 'action',
      page_url: 'https://app.test/billing?token=secret', metadata: { progress: 1, private: 'drop' }
    }

    assert_response :no_content
    assert_equal 1, payloads.size
    payload = payloads.first
    assert_equal '42', payload[:user_id]
    assert_equal 'Ada Lovelace', payload[:user_label]
    assert_equal 'gid://dummy/Organization/7', payload[:tenant]
    assert_equal 'https://app.test/billing', payload[:page_url]
    assert_equal({ 'progress' => '1' }, payload[:metadata])
    assert_nil payload[:visitor_token]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test 'gives anonymous signals a stable visitor cookie' do
    create_post
    post '/product_tours/widget/signal', params: { key: 'billing_setup', event_action: 'viewed', source: 'modal' }

    assert_response :no_content
    assert cookies['product_tours_vid'].present?
  end
end
