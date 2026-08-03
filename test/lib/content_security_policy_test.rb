# frozen_string_literal: true

require 'test_helper'

class ContentSecurityPolicyTest < ActiveSupport::TestCase
  test 'adds every supported iframe provider without replacing host sources' do
    policy = ActionDispatch::ContentSecurityPolicy.new
    policy.default_src :self
    policy.frame_src :self, 'https://frames.example.test'

    ProductTours::ContentSecurityPolicy.apply!(policy)

    sources = policy.directives.fetch('frame-src')
    assert_includes sources, "'self'"
    assert_includes sources, 'https://frames.example.test'
    ProductTours::ContentSecurityPolicy::FRAME_SOURCES.each { |source| assert_includes sources, source }
  end

  test 'inherits default sources when the host has no frame directive' do
    policy = ActionDispatch::ContentSecurityPolicy.new
    policy.default_src :self, 'https://default.example.test'

    ProductTours::ContentSecurityPolicy.apply!(policy)

    assert_equal ["'self'", 'https://default.example.test', *ProductTours::ContentSecurityPolicy::FRAME_SOURCES],
                 policy.directives.fetch('frame-src')
  end
end
