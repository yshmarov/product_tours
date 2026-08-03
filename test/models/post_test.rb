# frozen_string_literal: true

require 'test_helper'

class PostTest < ActiveSupport::TestCase
  test 'validates key format and uniqueness per locale' do
    create_post
    duplicate = ProductTours::Post.new(key: 'billing_setup', locale: 'en', title: 'Duplicate')
    translated = ProductTours::Post.new(key: 'billing_setup', locale: 'fr', title: 'Facturation')
    invalid = ProductTours::Post.new(key: 'Billing setup', locale: 'en', title: 'Invalid')

    refute duplicate.valid?
    assert translated.valid?
    refute invalid.valid?
    assert_includes invalid.errors[:key], 'is invalid'
  end

  test 'defaults locale and draft status' do
    post = ProductTours::Post.create!(key: 'welcome', title: 'Welcome')

    assert_equal I18n.default_locale.to_s, post.locale
    assert_predicate post, :draft?
  end

  test 'accepts only safe action URLs' do
    assert create_post(key: 'relative', action_url: '/settings').valid?
    assert create_post(key: 'absolute', action_url: 'https://example.com/settings').valid?

    %w[javascript:alert(1) //evil.example.test ftp://example.com/file].each_with_index do |url, index|
      post = ProductTours::Post.new(key: "unsafe_#{index}", locale: 'en', title: 'Unsafe', action_url: url)
      refute post.valid?, url
    end
  end

  test 'links to another post in the same locale' do
    destination = create_post(key: 'invite_team', title: 'Invite your team')
    source = create_post(key: 'welcome', action_post_key: destination.key)

    assert_equal destination, source.action_post
  end

  test 'rejects ambiguous, missing, cross-locale, and self-linked actions' do
    create_post(key: 'french_next', locale: 'fr')

    ambiguous = ProductTours::Post.new(key: 'ambiguous', locale: 'en', title: 'Ambiguous',
                                       action_url: '/settings', action_post_key: 'next_post')
    missing = ProductTours::Post.new(key: 'missing_link', locale: 'en', title: 'Missing',
                                     action_post_key: 'next_post')
    cross_locale = ProductTours::Post.new(key: 'cross_locale', locale: 'en', title: 'Cross locale',
                                          action_post_key: 'french_next')
    self_link = ProductTours::Post.new(key: 'self_link', locale: 'en', title: 'Self link',
                                       action_post_key: 'self_link')

    refute ambiguous.valid?
    assert_includes ambiguous.errors[:base], 'Primary action can open a URL or another post, not both'
    refute missing.valid?
    assert_includes missing.errors[:action_post_key], 'must identify an existing post in the same locale'
    refute cross_locale.valid?
    refute self_link.valid?
    assert_includes self_link.errors[:action_post_key], 'cannot link to the same post'
  end

  test 'derives provider metadata and rejects unsupported video URLs' do
    post = create_post(video_url: 'https://youtu.be/M7lc1UVf-VE')

    assert_equal 'youtube', post.video_metadata['provider']
    assert_equal 'M7lc1UVf-VE', post.video_metadata['provider_id']
    assert_includes post.video_metadata['embed_url'], 'youtube-nocookie.com'

    invalid = ProductTours::Post.new(key: 'bad_video', locale: 'en', title: 'Bad',
                                     video_url: 'https://youtube.com.evil.test/watch?v=M7lc1UVf-VE')
    refute invalid.valid?
  end

  test 'supports Action Text descriptions' do
    assert ProductTours::Post.description_supported?
    post = create_post(description: '<strong>Do this first</strong>')

    assert_includes post.description.to_s, 'Do this first'
  end

  test 'accepts video uploads and rejects other content types' do
    assert ProductTours::Post.video_upload_supported?
    post = create_post(key: 'uploaded')
    post.video.attach(io: StringIO.new('video'), filename: 'guide.webm', content_type: 'video/webm')
    assert post.save
    assert post.uploaded_video?

    invalid = create_post(key: 'not_video')
    invalid.video.attach(io: StringIO.new('text'), filename: 'notes.txt', content_type: 'text/plain')
    refute invalid.save
    assert_includes invalid.errors[:video], 'must be a video file'
  end
end
