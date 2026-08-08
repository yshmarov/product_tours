# frozen_string_literal: true

require 'test_helper'

class WidgetSystemTest < ApplicationSystemTestCase
  test 'moves forward, back, and finishes a linked walkthrough' do
    finish = create_post(key: 'browser_finish', title: 'Finish the walkthrough',
                         action_label: 'Finish walkthrough')
    middle = create_post(key: 'browser_middle', title: 'Review the feature',
                         action_post_key: finish.key)
    create_post(key: 'demo_walkthrough_start', title: 'Start the walkthrough',
                action_post_key: middle.key)

    visit '/sample'
    find('[data-product-tour="demo_walkthrough_start"]').click

    within '#product-tours-overlay' do
      assert_text 'Start the walkthrough'
      assert_no_button 'Back'

      click_button 'Next'
      assert_text 'Review the feature'
      assert_button 'Back'

      click_button 'Back'
      assert_text 'Start the walkthrough'
      assert_no_button 'Back'

      click_button 'Next'
      assert_text 'Review the feature'
      click_button 'Next'
      assert_text 'Finish the walkthrough'
      click_button 'Finish walkthrough'
    end

    assert_no_selector '#product-tours-overlay'
  end
end
