# frozen_string_literal: true

# A separate process: ractorize! freezes Rails and cannot share a process with
# the ordinary suite, whose tests deliberately replace configuration per test.
require 'tmpdir'
require 'fileutils'
require 'json'
require 'rack/mock'

ENV['RAILS_ENV'] = 'ractor'
ractor_directory = Dir.mktmpdir('product_tours-ractor-')
ENV['DATABASE_URL'] = "sqlite3:#{ractor_directory}/test.sqlite3"
at_exit { FileUtils.remove_entry(ractor_directory) }

require 'rails'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'active_storage/engine' if ENV['RACTOR_MEDIA'] == '1'
require 'action_text/engine' if ENV['RACTOR_MEDIA'] == '1' && ENV.fetch('RACTOR_TEXT', '1') == '1'
require 'product_tours'
require 'minitest/autorun'
require 'active_support/ractors'

raise 'Use Rails edge and Ruby 4.0+ for test:ractor' unless Rails::Application.method_defined?(:ractorize!) &&
                                                            defined?(Ractor.shareable_lambda)

ActiveSupport::Ractors.unshareable_proc_action = :raise
FileUtils.mkdir_p("#{ractor_directory}/config/environments")
File.write("#{ractor_directory}/config/environments/ractor.rb", "# Dedicated Ractor host\n")

class RactorHost < Rails::Application
  config.load_defaults 7.1
  config.secret_key_base = 'ractor-test-secret-not-used-outside-tests'
  config.eager_load = true
  config.enable_reloading = false
  config.hosts = []
  config.logger = ActiveSupport::Ractors::Logger.new(ENV['RACTOR_DEBUG'] ? $stderr : nil)
  config.cache_store = :null_store
  config.public_file_server.enabled = false
  config.action_dispatch.show_exceptions = :none
  config.action_controller.allow_forgery_protection = false
  config.active_record.maintain_test_schema = false
  config.i18n.available_locales = %i[en fr]
end
if defined?(ActiveStorage)
  RactorHost.config.active_storage.service = :ractor_test
  RactorHost.config.active_storage.service_configurations = {
    'ractor_test' => { 'service' => 'Disk', 'root' => "#{ractor_directory}/storage" }
  }
  RactorHost.config.active_job.queue_adapter = :inline
end
RactorHost.config.root = ractor_directory
File.write("#{ractor_directory}/config/routes.rb",
           "Rails.application.routes.draw { mount_product_tours at: '/product_tours' }\n")
ProductTours.config.enabled_environments = %w[ractor] if ProductTours.config.respond_to?(:enabled_environments)
RactorHost.initialize!
require_relative '../support/schema'

RactorUser = Data.define(:id, :email, :name)
ProductTours.configure do |config|
  config.enabled = ->(request) { request.get_header('HTTP_X_DISABLED') != 'yes' }
  config.authorize_admin = ->(request) { request.get_header('HTTP_X_ADMIN') == 'yes' }
  config.on_event = lambda do |_name, payload, request|
    actor = Ractor.main? ? 'main' : 'worker'
    ProductTours::Tour.find(payload[:tour_id]).update_column(:action_label,
                                                             "#{request.get_header('HTTP_X_USER')}:#{actor}")
  end
end
Rails.application.ractorize!

class RactorRequestsTest < Minitest::Test
  def start_request(method, path, params: {}, headers: {})
    input = params.is_a?(String) ? params : Rack::Utils.build_nested_query(params)
    content_type = headers.fetch('CONTENT_TYPE', 'application/x-www-form-urlencoded')
    options = headers.merge(method: method, 'CONTENT_TYPE' => content_type,
                            'CONTENT_LENGTH' => input.bytesize.to_s)
    env = Rack::MockRequest.env_for(path, options)
    env.delete('rack.input')
    env.delete('rack.errors')
    Ractor.new(env, input) do |environment, data|
      environment['rack.input'] = StringIO.new(data)
      environment['rack.errors'] = StringIO.new
      status, response_headers, response_body = Rails.application.call(environment)
      body = +''
      response_body.each { |part| body << part }
      response_body.close if response_body.respond_to?(:close)
      [status, response_headers, body]
    end
  end

  def request(...) = start_request(...).value

  def upload(path, fields:, field:, filename:, bytes:, content_type:, headers: {})
    boundary = 'ractor-upload-boundary'
    input = fields.map do |key, value|
      "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{key}\"\r\n\r\n#{value}\r\n"
    end.join
    input << "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{field}\"; filename=\"#{filename}\"\r\n"
    input << "Content-Type: #{content_type}\r\n\r\n#{bytes}\r\n--#{boundary}--\r\n"
    headers = headers.merge('CONTENT_TYPE' => "multipart/form-data; boundary=#{boundary}",
                            'REMOTE_ADDR' => '198.51.100.43', 'HTTP_X_USER' => 'upload')
    request('POST', path, params: input, headers: headers)
  end

  def test_upload_runs_in_a_worker_ractor
    skip 'Run with RACTOR_MEDIA=1 for Active Storage integration' unless defined?(ActiveStorage)

    bytes = File.binread(File.expand_path('../fixtures/files/clip.mp4', __dir__))
    fields = { 'tour[key]' => 'upload-tour', 'tour[title]' => 'upload', 'tour[status]' => 'draft',
               'video_source' => 'upload' }
    status, _, body = upload('/product_tours/tours', fields: fields,
                                                     field: 'tour[video]', filename: 'clip.mp4',
                                                     bytes: bytes, content_type: 'video/mp4',
                                                     headers: { 'HTTP_X_ADMIN' => 'yes' })
    assert_equal 302, status, body
    record = ProductTours::Tour.find_by!(key: 'upload-tour')
    assert_equal bytes, record.video.download
    assert_equal Digest::MD5.base64digest(bytes), record.video.blob.checksum
  end

  def test_media_streams_through_the_authorized_engine_route
    skip 'Run with RACTOR_MEDIA=1 for Active Storage integration' unless defined?(ActiveStorage)

    bytes = 'ractor-media-bytes'
    record = ProductTours::Tour.create!(key: 'media', locale: 'en', title: 'media', status: 'draft')
    record.video.attach(io: StringIO.new(bytes), filename: 'clip.mp4', content_type: 'video/mp4',
                        metadata: { analyzed: true })
    path = "/product_tours/media/#{record.id}"
    allowed = { 'HTTP_X_ADMIN' => 'yes' }
    status, _, body = request('GET', path)
    assert_equal 403, status, body
    status, headers, body = request('GET', path, headers: allowed)
    assert_equal 200, status, body
    assert_equal bytes, body
    assert_includes headers['cache-control'], 'private'
    assert_includes headers['cache-control'], 'no-store'
  end

  def test_simultaneous_worker_requests
    workers = 2.times.map { start_request('GET', '/product_tours/widget.js') }
    workers.each do |worker|
      status, _, body = worker.value
      assert_equal 200, status, body
    end
  end

  def test_assets_and_dashboard_render_in_non_main_ractors
    2.times do
      %w[widget.js dashboard.css dashboard.js].reject(&:empty?).each do |asset|
        status, headers, body = request('GET', "/product_tours/#{asset}")
        assert_equal 200, status, body
        refute_empty body
        assert_includes headers['content-type'], asset.end_with?('.css') ? 'css' : 'javascript'
      end
      status, _, body = request('GET', '/product_tours')
      assert_equal 403, status, body
      status, _, body = request('GET', '/product_tours', headers: { 'HTTP_X_ADMIN' => 'yes' })
      assert_equal 200, status, body
    end
  end

  def test_tour_resolution_and_lifecycle_callbacks_run_inside_worker_ractors
    tour = ProductTours::Tour.create!(key: 'ractor-tour', locale: 'en', title: 'Ractor tutorial', status: 'published')
    tour.update!(description: '<p>Ractor description</p>') if defined?(ActionText)
    status, _, body = request('GET', '/product_tours/widget/tour?key=ractor-tour')
    assert_equal 200, status, body
    assert_equal 'Ractor tutorial', JSON.parse(body).fetch('title')
    assert_includes JSON.parse(body).fetch('descriptionHtml'), 'Ractor description' if defined?(ActionText)
    status, _, body = request('POST', '/product_tours/widget/signal',
                              params: { key: 'ractor-tour', event_action: 'completed' },
                              headers: { 'HTTP_X_USER' => 'callback ran' })
    assert_equal 204, status, body
    assert_equal 'callback ran:worker', tour.reload.action_label
    status, _, body = request('POST', '/product_tours/widget/signal',
                              params: { key: 'ractor-tour', event_action: 'completed' },
                              headers: { 'HTTP_X_DISABLED' => 'yes' })
    assert_equal 403, status, body
  end
end
