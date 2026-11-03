# frozen_string_literal: true

require 'test_helper'

class WidgetSystemTest < ApplicationSystemTestCase
  test 'moves forward, back, and finishes a linked walkthrough' do
    finish = create_tour(key: 'browser_finish', title: 'Finish the walkthrough',
                         action_label: 'Finish walkthrough')
    middle = create_tour(key: 'browser_middle', title: 'Review the feature',
                         action_tour_key: finish.key)
    create_tour(key: 'demo_walkthrough_start', title: 'Start the walkthrough',
                action_tour_key: middle.key)

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

  test 'plays a direct video with its poster and a captions track' do
    create_tour(key: 'demo_walkthrough_start', title: 'Watch the guide',
                video_url: 'https://cdn.example.test/guide.mp4',
                poster_url: '/guide-poster.webp', captions_url: '/guide.en.vtt')

    visit '/sample'
    find('[data-product-tour="demo_walkthrough_start"]').click

    within '#product-tours-overlay' do
      player = find('video[aria-label="Watch the guide"]')
      assert_equal '/guide-poster.webp', URI(player[:poster]).path
      track = player.find('track', visible: :all)
      assert_equal %w[captions en English], [track[:kind], track[:srclang], track[:label]]
    end
  end
end
