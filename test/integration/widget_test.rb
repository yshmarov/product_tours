# frozen_string_literal: true

require 'test_helper'

class WidgetTest < ActionDispatch::IntegrationTest
  test 'renders a nonce-aware same-origin widget tag' do
    get '/sample'

    assert_response :ok
    assert_includes response.body, 'data-product-tours-config'
    assert_includes response.body, '<script src="/product_tours/widget.js?v='
    assert_includes response.body, 'nonce="testnonce"'
    assert_includes response.body, 'data-product-tour="demo_walkthrough_start"'
    assert_includes response.body, 'data-product-tour="demo_draft"'
    assert_includes response.body, 'data-product-tour="demo_missing_post"'
    refute_includes response.body, 'data-product-tour="demo_walkthrough_features"'
    ProductTours::ContentSecurityPolicy::FRAME_SOURCES.each do |source|
      assert_includes response.headers.fetch('Content-Security-Policy'), source
    end
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
    assert_includes response.body, 'element("div", "pt-head")'
    assert_includes response.body, 'background:rgba(0,0,0,.45)'
    assert_includes response.body, 'max-width:440px'
    assert_includes response.body, 'if (hasVideo) dialog.classList.add("pt-dialog-video")'
    assert_includes response.body, '.pt-dialog-video{max-width:760px}'
    refute_includes response.body, 'classList.remove("pt-dialog-video")'
    assert_includes response.body, 'border-radius:14px;padding:20px'
    assert_includes response.body, 'background:#2563eb'
    assert_includes response.body, 'height:100dvh;max-height:100dvh;border-radius:0'
    refute_includes response.body, 'animation:pt-enter'
    refute_includes response.body, 'title.tabIndex = -1'
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

  test 'resolves linked posts with a useful default action label' do
    create_post(key: 'next_step', title: 'Next step')
    create_post(action_post_key: 'next_step')

    get '/product_tours/widget/post', params: { key: 'billing_setup' }

    assert_response :ok
    payload = response.parsed_body
    assert_equal 'next_step', payload.dig('action', 'postKey')
    assert_equal 'Next', payload.dig('action', 'label')
    assert_nil payload.dig('action', 'url')
  end

  test 'reports unresolved draft and missing triggers without opening' do
    ProductTours::Seeds.load!
    events = []
    reports = []
    reporter = Object.new
    reporter.define_singleton_method(:report) do |error, handled:, severity:, context:, source:|
      reports << [error, { handled: handled, severity: severity, context: context, source: source }]
    end
    production = ActiveSupport::EnvironmentInquirer.new('production')
    original_environment = Rails.instance_variable_get(:@_env)
    Rails.instance_variable_set(:@_env, production)
    Rails.error.subscribe(reporter)
    subscriber = ActiveSupport::Notifications.subscribe('product_tours.unresolved_trigger') do |*args|
      events << args.last
    end

    get '/product_tours/widget/post', params: { key: 'demo_draft', page_url: 'https://app.test/path?secret=1' }
    assert_response :not_found
    assert_equal 'unpublished', events.last[:reason]
    assert_equal 'https://app.test/path', events.last[:page_url]

    get '/product_tours/widget/post', params: { key: 'demo_missing_post' }
    assert_response :not_found
    assert_equal 'missing', events.last[:reason]
    assert_equal 2, reports.size
    assert(reports.all? { |_error, options| options[:handled] == true })
    assert(reports.all? { |error, _options| error.is_a?(ProductTours::UnresolvedTriggerError) })
  ensure
    Rails.error.unsubscribe(reporter) if reporter
    Rails.instance_variable_set(:@_env, original_environment) if original_environment
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test 'raises unresolved triggers by default in test' do
    assert_raises(ProductTours::UnresolvedTriggerError) do
      get '/product_tours/widget/post', params: { key: 'Bad key' }
    end
  end

  test 'emits minimal lifecycle signals for host-owned analytics' do
    create_post
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
    assert_equal 'billing_setup', payload[:key]
    assert_equal 'en', payload[:locale]
    assert_equal 'action', payload[:source]
    assert_equal 'https://app.test/billing', payload[:page_url]
    refute_includes payload, :metadata
    refute_includes payload, :user_id
    refute_includes payload, :user_label
    refute_includes payload, :tenant
    refute_includes payload, :visitor_token
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test 'passes lifecycle signals and the raw request to the host hook' do
    create_post
    calls = []
    ProductTours.config.on_event = lambda do |name, payload, request|
      calls << [name, payload, request]
    end

    post '/product_tours/widget/signal', params: {
      key: 'billing_setup', event_action: 'viewed', source: 'modal',
      page_url: 'https://app.test/billing?token=secret'
    }, headers: { 'X-Product-Tours-Context' => 'workspace-123' }

    assert_response :no_content
    assert_equal 1, calls.size

    name, payload, raw_request = calls.first
    assert_equal 'product_tours.viewed', name
    assert_equal 'billing_setup', payload[:key]
    assert_equal 'https://app.test/billing', payload[:page_url]
    assert_instance_of ActionDispatch::Request, raw_request
    assert_equal '/product_tours/widget/signal', raw_request.path
    assert_equal 'workspace-123', raw_request.headers['X-Product-Tours-Context']
  end

  test 'does not let a raising host event hook break the visitor flow' do
    create_post
    called = false
    ProductTours.config.on_event = lambda do |_name, _payload, _request|
      called = true
      raise 'boom'
    end

    post '/product_tours/widget/signal', params: {
      key: 'billing_setup', event_action: 'completed', source: 'action'
    }

    assert_response :no_content
    assert called
  end

  test 'does not create a tracking cookie' do
    create_post
    post '/product_tours/widget/signal', params: { key: 'billing_setup', event_action: 'viewed', source: 'modal' }

    assert_response :no_content
    assert_nil cookies['product_tours_vid']
  end

  test 'resolves the requested locale and falls back to the default locale when missing' do
    create_post(title: 'English billing')

    get '/product_tours/widget/post', params: { key: 'billing_setup', locale: 'fr' }
    assert_response :ok
    assert_equal 'English billing', response.parsed_body['title']
    assert_equal 'en', response.parsed_body['locale']

    create_post(locale: 'fr', title: 'Facturation')
    get '/product_tours/widget/post', params: { key: 'billing_setup', locale: 'fr' }
    assert_response :ok
    assert_equal 'Facturation', response.parsed_body['title']
    assert_equal 'fr', response.parsed_body['locale']
  end

  test 'does not bypass a draft translation with a published default-locale tutorial' do
    create_post(title: 'English billing')
    create_post(locale: 'fr', title: 'Facturation', status: 'draft')

    error = assert_raises(ProductTours::UnresolvedTriggerError) do
      get '/product_tours/widget/post', params: { key: 'billing_setup', locale: 'fr' }
    end

    assert_equal 'unpublished', error.payload[:reason]
    assert_equal 'fr', error.payload[:locale]
  end

  test 'serves linked navigation behavior and localized Back copy' do
    get '/sample'
    config = response.body.match(%r{<script type="application/json" data-product-tours-config>(.*?)</script>})[1]

    assert_equal 'Back', JSON.parse(config).dig('labels', 'back')

    get '/product_tours/widget.js'
    assert_includes response.body, 'history.push(post)'
    assert_includes response.body, 'link would create a navigation cycle'
    assert_includes response.body, 'element("button", "pt-back"'
    refute_includes response.body, '"\\u2039 " + config.labels.back'
    assert_includes response.body, 'showFirstVideoFrame(player)'
    assert_includes response.body, 'fetchPost(key, config.locale)'
    assert_includes response.body, 'fetchPost(nextKey, post.locale)'
    assert_includes response.body, 'locale: session.locale'
    refute_includes response.body, 'video_ended'
    refute_includes response.body, 'next_key'
    refute_includes response.body, 'previous_key'
    refute_includes response.body, 'metadata: metadata'
  end
end
