# frozen_string_literal: true

require 'test_helper'
require 'yaml'

class LocalesTest < ActiveSupport::TestCase
  test 'ships the sibling gem locale set with matching keys' do
    files = Dir[ProductTours::Engine.root.join('config/locales/product_tours.*.yml')]
    assert_equal 26, files.size

    key_sets = files.map do |file|
      tree = YAML.safe_load_file(file)
      flatten(tree.values.first.fetch('product_tours'))
    end
    assert(key_sets.all? { |keys| keys == key_sets.first })
  end

  private

  def flatten(value, prefix = nil)
    value.flat_map do |key, child|
      path = [prefix, key].compact.join('.')
      child.is_a?(Hash) ? flatten(child, path) : path
    end.sort
  end
end
