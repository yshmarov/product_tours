# frozen_string_literal: true

ProductTours::Engine.routes.draw do
  get 'widget.js', to: 'widgets#show', as: :widget_script
  get 'dashboard.js', to: 'widgets#dashboard', as: :dashboard_script
  get 'dashboard.css', to: 'widgets#dashboard_stylesheet', as: :dashboard_stylesheet

  scope :widget, as: :widget do
    get :post, to: 'tours#resolve'
    post :signal, to: 'tours#signal'
  end

  # No `id: /\d+/` constraint: it made this route bigint-only, which forced the
  # table to be bigint too, and a uuid-keyed host could then never attach a video
  # (its active_storage_attachments.record_id is a uuid column). Every
  # fixed-name route above is declared first, so ordering already disambiguates.
  get 'media/:id', to: 'media#show', as: :media

  resources :posts do
    post :refresh_video_metadata, on: :member
    post :add_translation, on: :member
    patch :publish, on: :member
    patch :unpublish, on: :member
    get :video_preview, on: :collection
  end
  root to: 'posts#index'
end
