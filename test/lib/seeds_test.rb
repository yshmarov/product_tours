# frozen_string_literal: true

require 'test_helper'

class SeedsTest < ActiveSupport::TestCase
  test 'loads an idempotent provider matrix' do
    first = ProductTours::Seeds.load!
    second = ProductTours::Seeds.load!

    assert_equal 11, first.size
    assert_equal first.map(&:id), second.map(&:id)
    assert_equal 11, ProductTours::Post.where("key LIKE 'demo_%'").count
    assert_equal %w[direct loom tella vimeo voomly youtube],
                 first.filter_map { |post| post.resolved_video&.dig(:provider) }.sort
    assert_equal 10, first.count(&:published?)
    assert_equal ['demo_draft'], first.reject(&:published?).map(&:key)
  end

  test 'loads a linked walkthrough through every video provider' do
    ProductTours::Seeds.load!

    current = ProductTours::Post.find_by!(locale: 'en', key: 'demo_walkthrough_start')
    keys = []
    providers = []
    loop do
      keys << current.key
      providers << current.resolved_video[:provider] if current.resolved_video
      break if current.action_post_key.blank?

      current = current.action_post
    end

    assert_equal %w[
      demo_walkthrough_start demo_walkthrough_features demo_youtube demo_vimeo
      demo_loom demo_tella demo_voomly demo_direct_video demo_walkthrough_finish
    ], keys
    assert_equal %w[youtube vimeo loom tella voomly direct], providers
    assert_equal 'Get started', current.action_label
  end

  test 'loads translated demo posts for all demo locales' do
    first = ProductTours::Seeds.load_all!
    second = ProductTours::Seeds.load_all!

    assert_equal 33, first.size
    assert_equal first.map(&:id), second.map(&:id)
    assert_equal ProductTours::Seeds::DEMO_LOCALES.sort,
                 ProductTours::Post.distinct.order(:locale).pluck(:locale).sort
    assert_equal 'Bien démarrer', ProductTours::Post.find_by!(locale: 'fr', key: 'demo_getting_started').title
    assert_equal 'Първи стъпки', ProductTours::Post.find_by!(locale: 'bg', key: 'demo_getting_started').title
    assert_equal 'Présentation des fournisseurs vidéo',
                 ProductTours::Post.find_by!(locale: 'fr', key: 'demo_walkthrough_start').title
    assert_equal 3, ProductTours::Post.where(key: 'demo_draft', status: 'draft').count
  end

  test 'automatically seeds only development installs' do
    development = ActiveSupport::EnvironmentInquirer.new('development')
    production = ActiveSupport::EnvironmentInquirer.new('production')

    assert_empty ProductTours::Seeds.load_for_install!(environment: production)
    assert_equal 0, ProductTours::Post.count

    assert_equal 11, ProductTours::Seeds.load_for_install!(environment: development).size
    assert_equal 11, ProductTours::Post.count
  end

  test 'provides copy-ready entry buttons without exposing internal walkthrough posts' do
    html = ProductTours::Seeds.trigger_html

    assert_includes html, 'data-product-tour="demo_walkthrough_start"'
    assert_includes html, 'data-product-tour="demo_youtube"'
    assert_includes html, 'data-product-tour="demo_draft"'
    assert_includes html, 'data-product-tour="demo_missing_post"'
    assert_includes html, '<%= product_tours_tag %>'
    refute_includes html, 'data-product-tour="demo_walkthrough_features"'
    refute_includes html, 'data-product-tour="demo_walkthrough_finish"'

    ProductTours::Seeds.load!
    assert ProductTours::Post.find_by!(locale: 'en', key: 'demo_draft').draft?
    refute ProductTours::Post.exists?(locale: 'en', key: 'demo_missing_post')
  end
end
