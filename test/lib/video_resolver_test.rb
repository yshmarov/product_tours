# frozen_string_literal: true

require 'test_helper'

class VideoResolverTest < ActiveSupport::TestCase
  test 'resolves every supported iframe provider' do
    cases = [
      ['https://www.youtube.com/shorts/M7lc1UVf-VE', 'youtube', 'youtube-nocookie.com/embed/M7lc1UVf-VE'],
      ['https://vimeo.com/123456789/abc123def0', 'vimeo', 'player.vimeo.com/video/123456789?h=abc123def0'],
      ['https://www.loom.com/share/e5b8c04bca094dd8a5507925ab887002', 'loom',
       'loom.com/embed/e5b8c04bca094dd8a5507925ab887002'],
      ['https://www.tella.tv/video/add-your-logo-to-videos-39y0', 'tella',
       'tella.tv/video/add-your-logo-to-videos-39y0/embed'],
      ['https://share.voomly.com/v/' \
       'CxfDyNYKE0SBEBV-zVAUHo8rNwS2eLBr418z81gd6GlkKlLfJ', 'voomly',
       'embed.voomly.com/embed/assets/embed.html?videoId=']
    ]

    cases.each do |url, provider, source|
      resolved = ProductTours::VideoResolver.resolve(url)
      assert_equal provider, resolved.provider, url
      assert_includes resolved.url, source, url
      assert resolved.iframe?
    end
  end

  test 'preserves Vimeo privacy hashes from player URLs' do
    resolved = ProductTours::VideoResolver.resolve('https://player.vimeo.com/video/123456789?h=abc123def0')

    assert_equal 'https://player.vimeo.com/video/123456789?h=abc123def0', resolved.url
  end

  test 'resolves direct MP4 and WebM URLs' do
    %w[https://cdn.example.test/guide.mp4 https://cdn.example.test/guide.webm].each do |url|
      resolved = ProductTours::VideoResolver.resolve(url)
      assert resolved.direct?
      assert_equal url, resolved.url
    end
  end

  test 'fails closed for schemes, lookalikes, and non-video paths' do
    urls = [
      'http://youtube.com/watch?v=M7lc1UVf-VE',
      'https://youtube.com.evil.test/watch?v=M7lc1UVf-VE',
      'https://vimeo.com/channels/staffpicks',
      'https://cdn.example.test/video.mov',
      'javascript:alert(1)'
    ]

    urls.each { |url| assert_nil ProductTours::VideoResolver.resolve(url), url }
  end
end
