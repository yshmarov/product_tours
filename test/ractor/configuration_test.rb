# frozen_string_literal: true

require 'rails'
require 'product_tours'
require 'active_support/test_case'
require 'minitest/autorun'

class RactorSupportTest < ActiveSupport::TestCase
  setup do
    skip 'Ractor callback isolation requires Ruby 4.0+' unless defined?(Ractor.shareable_lambda)
  end

  test 'default callbacks and configuration work inside a non-main Ractor' do
    original = ProductTours::Configuration.new
    shared = ProductTours::RactorSupport.configuration(original)
    assert Ractor.shareable?(shared)
    assert_predicate shared, :frozen?
    refute_predicate original, :frozen?
    assert Ractor.new(shared) { |config| config.enabled.call(nil) }.value
    assert_nil Ractor.new(shared) { |config| config.current_user.call(nil) }.value if shared.respond_to?(:current_user)
  end

  test 'request callbacks keep lambda arity and run separately for each request' do
    original = ProductTours::Configuration.new
    callback = ->(request) { request.fetch(:allowed) }
    original.enabled = callback
    shared = ProductTours::RactorSupport.configuration(original)
    assert_predicate shared.enabled, :lambda?
    assert_equal 1, shared.enabled.arity
    assert_equal [true, false], Ractor.new(shared) { |config|
      [config.enabled.call(allowed: true), config.enabled.call(allowed: false)]
    }.value
    assert_same callback, original.enabled
    refute_predicate original.enabled, :frozen?
  end

  test 'unsafe callback captures fail with the setting name without mutating the original' do
    state = []
    original = ProductTours::Configuration.new
    original.enabled = ->(_request) { state << true }
    error = assert_raises(ArgumentError) { ProductTours::RactorSupport.configuration(original) }
    assert_includes error.message, 'ProductTours.config.enabled'
    assert_empty state
    refute_predicate original, :frozen?
    original.enabled.call(nil)
    assert_equal [true], state
  end

  test 'isolated callbacks preserve explicit shareable receivers' do
    original = ProductTours::Configuration.new
    original.enabled = Ractor.shareable_lambda(self: ProductTours) { |_request| self == ProductTours }
    shared = ProductTours::RactorSupport.configuration(original)
    assert Ractor.new(shared) { |config| config.enabled.call(nil) }.value
    assert_same original.enabled, shared.enabled
  end

  test 'ordinary procs retain their lenient arity' do
    original = ProductTours::Configuration.new
    original.enabled = proc { |request| request }
    shared = ProductTours::RactorSupport.configuration(original)
    refute_predicate shared.enabled, :lambda?
    assert Ractor.new(shared) { |config| config.enabled.call(true, :ignored) }.value
  end

  test 'freezing a snapshot leaves host values mutable and detached' do
    original = ProductTours::Configuration.new
    original.mount_path = +'/custom'
    shared = ProductTours::RactorSupport.configuration(original)
    original.mount_path << '/changed'
    assert_equal '/custom', shared.mount_path
    assert_equal '/custom/changed', original.mount_path
    assert_predicate shared.mount_path, :frozen?
  end

  test 'ordinary configuration remains mutable without ractorize' do
    ProductTours.config.enabled = ->(_request) { false }
    refute ProductTours.config.enabled.call(nil)
    refute_predicate ProductTours.config, :frozen?
  end
end
