# frozen_string_literal: true

require 'test_helper'

class DashboardTest < ActionDispatch::IntegrationTest
  test 'is forbidden without admin authorization' do
    get '/product_tours'
    assert_response :forbidden
  end

  test 'lists, creates, edits, and deletes posts' do
    as_admin!
    post '/product_tours/posts', params: {
      post: { key: 'invite_team', locale: 'en', status: 'published', title: 'Invite your team',
              description: 'Add your first teammate', action_label: 'Open team', action_url: '/team' }
    }
    created = ProductTours::Post.find_by!(key: 'invite_team')
    assert_redirected_to "/product_tours/posts/#{created.id}"

    get '/product_tours'
    assert_includes response.body, 'Invite your team'
    assert_includes response.body, 'invite_team'
    assert_includes response.body, 'class="dashboard-shell '
    assert_includes response.body, 'class="dashboard-sidebar"'
    assert_includes response.body, 'class="record-row"'
    refute_includes response.body, 'record-time'

    get "/product_tours/posts?post_id=#{created.id}"
    assert_includes response.body, 'class="post-panel"'
    assert_includes response.body, 'class="card pad preview-card"'

    patch "/product_tours/posts/#{created.id}", params: { post: { status: 'draft', title: 'Invite teammates' } }
    assert_equal 'draft', created.reload.status
    assert_equal 'Invite teammates', created.title

    delete "/product_tours/posts/#{created.id}"
    assert_redirected_to '/product_tours/posts'
    assert_not ProductTours::Post.exists?(created.id)
  end

  test 'loads dashboard assets without inline handlers' do
    as_admin!
    create_post
    get '/product_tours'

    assert_response :ok
    assert_includes response.body, 'href="/product_tours/dashboard.css?v='
    assert_includes response.body, 'src="/product_tours/dashboard.js?v='
    refute_includes response.body, 'onchange='
    refute_includes response.body, 'onclick='

    get '/product_tours/posts/new'
    assert_includes response.body, 'data-rich-content'
    assert_includes response.body, 'data-rich-command="bold"'
    refute_includes response.body, '<trix-editor'
  end

  test 'suggests keys for the selected status and locale' do
    as_admin!
    create_post(key: 'english_published')
    create_post(key: 'french_published', locale: 'fr')
    create_post(key: 'english_draft', status: 'draft')

    get '/product_tours/posts', params: { status: 'published', locale: 'en' }

    assert_response :ok
    assert_select 'input[type=search][list=product-tour-key-options]', count: 1
    assert_select 'datalist#product-tour-key-options option[value=english_published]', count: 1
    assert_select 'datalist#product-tour-key-options option[value=french_published]', count: 0
    assert_select 'datalist#product-tour-key-options option[value=english_draft]', count: 0
  end

  test 'does not purge an upload when an edit fails validation' do
    as_admin!
    tour = create_post(key: 'uploaded_tour')
    tour.video.attach(io: StringIO.new('video'), filename: 'guide.webm', content_type: 'video/webm')

    patch "/product_tours/posts/#{tour.id}", params: {
      post: { key: 'Invalid key', title: tour.title, locale: tour.locale,
              status: tour.status, remove_video: '1' }
    }

    assert_response :unprocessable_entity
    assert tour.reload.uploaded_video?

    patch "/product_tours/posts/#{tour.id}", params: {
      post: { key: tour.key, title: tour.title, locale: tour.locale,
              status: tour.status, remove_video: '1' }
    }
    refute tour.reload.uploaded_video?
  end

  test 'can use a host admin layout' do
    as_admin!
    ProductTours.config.admin_layout = 'host_admin'
    create_post

    get '/product_tours'
    assert_includes response.body, 'data-host-admin-layout="product_tours"'
  end
end
