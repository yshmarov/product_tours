# frozen_string_literal: true

require_relative 'lib/product_tours/version'

Gem::Specification.new do |spec|
  spec.name = 'product_tours'
  spec.version = ProductTours::VERSION
  spec.authors = ['Yaroslav Shmarov']
  spec.email = ['yaroslav.shmarov@clickfunnels.com']

  spec.summary = 'Self-hosted product tours and video tutorials for Rails apps.'
  spec.description = <<~DESCRIPTION
    A mountable Rails engine for publishing in-app product tutorials, linking
    them into lightweight walkthroughs, and opening them from host-owned buttons
    or links. Content, videos, and admin UI stay in your Rails application;
    lifecycle activity is exposed through ActiveSupport::Notifications for the
    analytics system you already use.
  DESCRIPTION
  spec.homepage = 'https://github.com/yshmarov/product_tours'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = "#{spec.homepage}/tree/main"
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri'] = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir[
    'app/**/*',
    'config/**/*',
    'lib/**/*',
    'MIT-LICENSE',
    'Rakefile',
    'README.md',
    'CHANGELOG.md'
  ]
  spec.require_paths = ['lib']

  spec.add_dependency 'rails', '>= 7.1'
end
