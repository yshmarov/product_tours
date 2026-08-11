# frozen_string_literal: true

require 'test_helper'

class MediaTest < ActionDispatch::IntegrationTest
  setup do
    @content = '0123456789video'
    @tour = create_tour(key: 'uploaded_media')
    @tour.video.attach(io: StringIO.new(@content), filename: 'guide.webm', content_type: 'video/webm')
  end

  test 'streams a published upload through the authorized engine route' do
    get "/product_tours/media/#{@tour.id}"

    assert_response :success
    assert_equal 'video/webm', response.media_type
    assert_equal @content, response.body
    assert_equal 'bytes', response.headers['Accept-Ranges']
    assert_includes response.headers['Cache-Control'], 'no-store'
    refute response.redirect?
    assert_nil response.headers['Location']
  end

  test 'supports byte ranges without exposing a blob URL' do
    get "/product_tours/media/#{@tour.id}", headers: { 'Range' => 'bytes=2-5' }

    assert_response :partial_content
    assert_equal '2345', response.body
    assert_equal "bytes 2-5/#{@content.bytesize}", response.headers['Content-Range']
    assert_equal 'bytes', response.headers['Accept-Ranges']
    assert_nil response.headers['Location']
  end

  test 'keeps draft uploads behind the admin gate' do
    @tour.update!(status: 'draft')

    get "/product_tours/media/#{@tour.id}"
    assert_response :forbidden

    as_admin!
    get "/product_tours/media/#{@tour.id}"
    assert_response :success
    assert_equal @content, response.body
  end
end
