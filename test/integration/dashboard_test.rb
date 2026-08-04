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
    assert_select "a[href='/product_tours/posts/new']", text: 'New product tour'
    assert_includes response.body, 'Invite your team'
    assert_includes response.body, 'invite_team'
    assert_includes response.body, 'class="dashboard-shell '
    assert_includes response.body, 'class="dashboard-sidebar"'
    assert_includes response.body, 'class="record-row"'
    refute_includes response.body, 'record-time'
    assert_select '.tabs a' do |tabs|
      assert_match(/Published/, tabs.first.text)
      assert_match(/Draft/, tabs[1].text)
    end

    get "/product_tours/posts?post_id=#{created.id}"
    assert_includes response.body, 'class="detail-panel"'
    assert_includes response.body, 'class="card pad preview-card"'
    assert_select '.translations-card h2', text: 'Languages'
    assert_select "form[action='/product_tours/posts/#{created.id}/add_translation']"

    get "/product_tours/posts/#{created.id}"
    assert_select '.detail-panel .panel-head', count: 0
    assert_select '.preview-card > h2', text: 'Invite your team'
    assert_select '.preview-card > h2', text: 'Preview', count: 0
    assert_select '.details-card' do
      assert_select 'h2', text: 'Details', count: 0
      assert_select 'dt', text: 'Key'
      assert_select 'dd code.key', text: 'invite_team'
      assert_select 'dt', text: 'Language'
      assert_select 'dd .badge.locale', text: 'en'
      assert_select 'dt', text: 'Publication status'
      assert_select 'dd .badge.status-published', text: 'Published'
      assert_select '.actions.details-actions' do
        assert_select "a[href='/product_tours/posts/#{created.id}/edit']", text: 'Edit'
        assert_select "form[action='/product_tours/posts/#{created.id}/unpublish'] button", text: 'Move to drafts'
        assert_select "form[action='/product_tours/posts/#{created.id}'] button", text: 'Delete'
      end
    end
    assert_select '.detail-scroll > .actions', count: 0

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
    assert_select 'h1', text: 'New product tour'
    assert_includes response.body, 'data-rich-content'
    assert_includes response.body, 'data-rich-command="bold"'
    assert_includes response.body, 'Continue to another tutorial'
    assert_includes response.body, 'automatically adds a Back button'
    assert_includes response.body, 'data-action-post-select'
    assert_select 'input#post_locale[disabled][value=en]', count: 1
    assert_select 'select#post_locale', count: 0
    assert_includes response.body, 'data-video-preview-input'
    assert_select '.field-grid', count: 0
    assert_select 'label[for=post_key]', text: 'Trigger key'
    assert_select 'label[for=post_locale]', text: 'Language'
    assert_select 'label[for=post_status]', text: 'Publication status'
    assert_select 'input[name=video_source][value=url][checked]', count: 1
    assert_select 'input[name=video_source][value=upload]', count: 1
    assert_select '[data-video-source-fields=upload][hidden]', count: 1
    assert_includes response.body, 'data-endpoint="/product_tours/posts/video_preview"'
    refute_includes response.body, 'class="card pad form-card"'
    refute_includes response.body, '<trix-editor'

    get '/product_tours/dashboard.js'
    assert_includes response.body, 'function normalizeKey'
    assert_includes response.body, 'showFirstVideoFrame'
    assert_includes response.body, 'function syncVideoSourcePicker'

    get '/product_tours/dashboard.css'
    assert_includes response.body, '.pt-show .detail-panel { width: 100%; }'
    refute_includes response.body, '.pt-show .detail-panel { max-width:'
  end

  test 'previews supported video URLs for the form' do
    as_admin!

    get '/product_tours/posts/video_preview', params: { url: 'https://cdn.example.test/tutorial.mp4' }

    assert_response :ok
    assert_equal({ 'kind' => 'direct', 'provider' => 'direct',
                   'url' => 'https://cdn.example.test/tutorial.mp4' }, response.parsed_body)

    get '/product_tours/posts/video_preview', params: { url: 'https://example.test/tutorial' }
    assert_response :unprocessable_entity
  end

  test 'publishes and unpublishes a post from explicit dashboard actions' do
    as_admin!
    draft = create_post(status: 'draft')

    get "/product_tours/posts/#{draft.id}"
    assert_select "form[action='/product_tours/posts/#{draft.id}/publish'] button", text: 'Publish'

    patch "/product_tours/posts/#{draft.id}/publish"
    assert_redirected_to "/product_tours/posts/#{draft.id}"
    assert draft.reload.published?

    get "/product_tours/posts/#{draft.id}"
    assert_select "form[action='/product_tours/posts/#{draft.id}/unpublish'] button", text: 'Move to drafts'

    patch "/product_tours/posts/#{draft.id}/unpublish"
    assert_redirected_to "/product_tours/posts/#{draft.id}"
    assert draft.reload.draft?
  end

  test 'creates linked posts and clears the inactive action destination' do
    as_admin!
    destination = create_post(key: 'invite_team', title: 'Invite your team')

    post '/product_tours/posts', params: {
      action_target: 'post',
      post: { key: 'welcome', locale: 'en', status: 'published', title: 'Welcome',
              action_label: '', action_url: '/unused', action_post_key: destination.key }
    }

    created = ProductTours::Post.find_by!(key: 'welcome')
    assert_equal destination.key, created.action_post_key
    assert_nil created.action_url

    get "/product_tours/posts/#{created.id}/edit"
    assert_select 'input[name=action_target][value=post][checked]'
    assert_select 'select#post_action_post_key option[selected][value=invite_team]'

    patch "/product_tours/posts/#{created.id}", params: {
      action_target: 'close', post: { title: created.title, action_post_key: destination.key }
    }
    assert_nil created.reload.action_post_key
  end

  test 'sidebar and new tutorial use only the default locale' do
    as_admin!
    create_post(key: 'english_published')
    create_post(key: 'french_published', locale: 'fr', title: 'French only')
    create_post(key: 'english_draft', status: 'draft')

    get '/product_tours/posts', params: { status: 'published' }

    assert_response :ok
    assert_includes response.body, 'Set up billing'
    refute_includes response.body, 'French only'
    assert_select '.filters select', count: 0
    assert_select 'input[type=search][list=product-tour-key-options]', count: 1
    assert_select 'datalist#product-tour-key-options option[value=english_published]', count: 1
    assert_select 'datalist#product-tour-key-options option[value=french_published]', count: 0
    assert_select 'datalist#product-tour-key-options option[value=english_draft]', count: 0

    post '/product_tours/posts', params: {
      post: { key: 'forced_default', locale: 'fr', status: 'draft', title: 'Default language' }
    }

    assert_equal I18n.default_locale.to_s, ProductTours::Post.find_by!(key: 'forced_default').locale
  end

  test 'clears the dashboard search and filters' do
    as_admin!
    create_post(key: 'demo_direct_video')

    get '/product_tours/posts', params: { status: 'published', q: 'demo_direct_video', commit: 'Search' }

    assert_response :ok
    assert_select '.filters input[type=search][value=demo_direct_video]'
    assert_select '.filters a.filters-clear[href="/product_tours/posts"]', text: 'Clear'

    get '/product_tours/posts'
    assert_select '.filters a.filters-clear', count: 0
  end

  test 'adds and manages translations from a tutorial' do
    as_admin!
    original = create_post(description: 'Translate this description')
    original.video.attach(io: StringIO.new('video'), filename: 'guide.webm', content_type: 'video/webm')

    post "/product_tours/posts/#{original.id}/add_translation", params: { locale: 'fr' }

    translation = ProductTours::Post.find_by!(key: original.key, locale: 'fr')
    assert_redirected_to "/product_tours/posts/#{translation.id}/edit"
    assert translation.draft?
    assert_equal original.title, translation.title
    assert_includes translation.description.to_plain_text, 'Translate this description'
    assert_equal original.video.blob_id, translation.video.blob_id

    get "/product_tours/posts/#{original.id}"
    assert_select '.translations-card' do
      assert_select '.translation-row .badge.locale', text: 'English (en)'
      assert_select '.translation-row .badge.locale', text: 'French (fr)'
      assert_select "a[href='/product_tours/posts/#{translation.id}']", text: 'Open'
      assert_select "form[action='/product_tours/posts/#{original.id}/add_translation']"
      assert_select 'select[name=locale] option[value=ar]', count: 1
      assert_select 'select[name=locale] option[value=ar]', text: 'Arabic (ar)'
      assert_select 'select[name=locale] option[value=en]', count: 0
      assert_select 'select[name=locale] option[value=fr]', count: 0
    end

    assert_select ".translations-card a[href='/product_tours/posts/#{translation.id}']", text: 'Open'

    get '/product_tours/posts', params: { status: 'published', post_id: original.id }
    assert_select ".translations-card a[href^='/product_tours/posts?'][href*='post_id=#{translation.id}']", text: 'Open'

    get "/product_tours/posts/#{original.id}/edit"
    assert_select 'input#post_key[disabled]', count: 1
    assert_select 'input#post_locale[disabled][value=en]', count: 1

    get "/product_tours/posts/#{translation.id}/edit"
    assert_select 'input#post_key[disabled]', count: 1
    assert_select 'input#post_locale[disabled][value=fr]', count: 1
    delete "/product_tours/posts/#{original.id}"
    assert_redirected_to "/product_tours/posts/#{original.id}"
    assert ProductTours::Post.exists?(original.id)

    delete "/product_tours/posts/#{translation.id}"
    refute ProductTours::Post.exists?(translation.id)
  end

  test 'does not purge an upload when an edit fails validation' do
    as_admin!
    tour = create_post(key: 'uploaded_tour')
    tour.video.attach(io: StringIO.new('video'), filename: 'guide.webm', content_type: 'video/webm')

    patch "/product_tours/posts/#{tour.id}", params: {
      video_source: 'url',
      post: { key: 'Invalid key', title: tour.title, locale: tour.locale,
              status: tour.status }
    }

    assert_response :unprocessable_entity
    assert tour.reload.uploaded_video?

    patch "/product_tours/posts/#{tour.id}", params: {
      video_source: 'url',
      post: { key: tour.key, title: tour.title, locale: tour.locale,
              status: tour.status }
    }
    refute tour.reload.uploaded_video?
  end

  test 'keeps only the selected video source' do
    as_admin!
    tour = create_post(video_url: 'https://cdn.example.test/old.mp4')

    patch "/product_tours/posts/#{tour.id}", params: {
      video_source: 'upload',
      post: { title: tour.title, video: fake_video }
    }

    assert_redirected_to "/product_tours/posts/#{tour.id}"
    assert tour.reload.uploaded_video?
    assert_nil tour.video_url
  end

  test 'can use a host admin layout' do
    as_admin!
    ProductTours.config.admin_layout = 'host_admin'
    create_post

    get '/product_tours'
    assert_includes response.body, 'data-host-admin-layout="product_tours"'
  end
end
