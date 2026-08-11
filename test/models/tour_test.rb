# frozen_string_literal: true

require 'test_helper'

class TourTest < ActiveSupport::TestCase
  test 'validates key format and uniqueness per locale' do
    create_tour
    duplicate = ProductTours::Tour.new(key: 'billing_setup', locale: 'en', title: 'Duplicate')
    translated = ProductTours::Tour.new(key: 'billing_setup', locale: 'fr', title: 'Facturation')
    invalid = ProductTours::Tour.new(key: 'Billing setup', locale: 'en', title: 'Invalid')

    refute duplicate.valid?
    assert translated.valid?
    refute invalid.valid?
    assert_includes invalid.errors[:key], 'is invalid'
  end

  test 'defaults locale and draft status' do
    tour = ProductTours::Tour.create!(key: 'welcome', title: 'Welcome')

    assert_equal I18n.default_locale.to_s, tour.locale
    assert_predicate tour, :draft?
  end

  test 'accepts only safe action URLs' do
    assert create_tour(key: 'relative', action_url: '/settings').valid?
    assert create_tour(key: 'absolute', action_url: 'https://example.com/settings').valid?

    %w[javascript:alert(1) //evil.example.test ftp://example.com/file].each_with_index do |url, index|
      tour = ProductTours::Tour.new(key: "unsafe_#{index}", locale: 'en', title: 'Unsafe', action_url: url)
      refute tour.valid?, url
    end
  end

  test 'links to another tour in the same locale' do
    destination = create_tour(key: 'invite_team', title: 'Invite your team')
    source = create_tour(key: 'welcome', action_tour_key: destination.key)

    assert_equal destination, source.action_tour
  end

  test 'rejects ambiguous, missing, cross-locale, and self-linked actions' do
    create_tour(key: 'french_next', locale: 'fr')

    ambiguous = ProductTours::Tour.new(key: 'ambiguous', locale: 'en', title: 'Ambiguous',
                                       action_url: '/settings', action_tour_key: 'next_tour')
    missing = ProductTours::Tour.new(key: 'missing_link', locale: 'en', title: 'Missing',
                                     action_tour_key: 'next_tour')
    cross_locale = ProductTours::Tour.new(key: 'cross_locale', locale: 'en', title: 'Cross locale',
                                          action_tour_key: 'french_next')
    self_link = ProductTours::Tour.new(key: 'self_link', locale: 'en', title: 'Self link',
                                       action_tour_key: 'self_link')

    refute ambiguous.valid?
    assert_includes ambiguous.errors[:base], 'Primary action can open a URL or another tour, not both'
    refute missing.valid?
    assert_includes missing.errors[:action_tour_key], 'must identify an existing tour in the same locale'
    refute cross_locale.valid?
    refute self_link.valid?
    assert_includes self_link.errors[:action_tour_key], 'cannot link to the same tour'
  end

  test 'derives provider metadata and rejects unsupported video URLs' do
    tour = create_tour(video_url: 'https://youtu.be/M7lc1UVf-VE')

    assert_equal 'youtube', tour.video_metadata['provider']
    assert_equal 'M7lc1UVf-VE', tour.video_metadata['provider_id']
    assert_includes tour.video_metadata['embed_url'], 'youtube-nocookie.com'

    invalid = ProductTours::Tour.new(key: 'bad_video', locale: 'en', title: 'Bad',
                                     video_url: 'https://youtube.com.evil.test/watch?v=M7lc1UVf-VE')
    refute invalid.valid?
  end

  test 'supports Action Text descriptions' do
    assert ProductTours::Tour.description_supported?
    tour = create_tour(description: '<strong>Do this first</strong>')

    assert_includes tour.description.to_s, 'Do this first'
  end

  test 'accepts video uploads and rejects other content types' do
    assert ProductTours::Tour.video_upload_supported?
    tour = create_tour(key: 'uploaded')
    tour.video.attach(io: StringIO.new('video'), filename: 'guide.webm', content_type: 'video/webm')
    assert tour.save
    assert tour.uploaded_video?

    invalid = create_tour(key: 'not_video')
    invalid.video.attach(io: StringIO.new('text'), filename: 'notes.txt', content_type: 'text/plain')
    refute invalid.save
    assert_includes invalid.errors[:video], 'must be a video file'
  end
end
