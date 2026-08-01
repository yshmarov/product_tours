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
