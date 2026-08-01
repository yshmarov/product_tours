# frozen_string_literal: true

require 'test_helper'

class SeedsTest < ActiveSupport::TestCase
  test 'loads an idempotent provider matrix' do
    first = ProductTours::Seeds.load!
    second = ProductTours::Seeds.load!

    assert_equal 7, first.size
    assert_equal first.map(&:id), second.map(&:id)
    assert_equal 7, ProductTours::Post.where("key LIKE 'demo_%'").count
    assert_equal %w[direct loom tella vimeo voomly youtube],
                 first.filter_map { |post| post.resolved_video&.dig(:provider) }.sort
    assert first.all?(&:published?)
  end

  test 'loads translated demo posts for all demo locales' do
    first = ProductTours::Seeds.load_all!
    second = ProductTours::Seeds.load_all!

    assert_equal 21, first.size
    assert_equal first.map(&:id), second.map(&:id)
    assert_equal ProductTours::Seeds::DEMO_LOCALES.sort,
                 ProductTours::Post.distinct.order(:locale).pluck(:locale).sort
    assert_equal 'Bien démarrer', ProductTours::Post.find_by!(locale: 'fr', key: 'demo_getting_started').title
    assert_equal 'Първи стъпки', ProductTours::Post.find_by!(locale: 'bg', key: 'demo_getting_started').title
  end
end
