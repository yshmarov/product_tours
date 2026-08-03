# frozen_string_literal: true

ProductTours::Engine.routes.draw do
  get 'widget.js', to: 'widgets#show', as: :widget_script
  get 'dashboard.js', to: 'widgets#dashboard', as: :dashboard_script
  get 'dashboard.css', to: 'widgets#dashboard_stylesheet', as: :dashboard_stylesheet

  scope :widget, as: :widget do
    get :post, to: 'tours#resolve'
    post :signal, to: 'tours#signal'
  end

  get 'media/:id', to: 'media#show', as: :media, constraints: { id: /\d+/ }

  resources :posts do
    post :refresh_video_metadata, on: :member
    post :add_translation, on: :member
    patch :publish, on: :member
    patch :unpublish, on: :member
    get :video_preview, on: :collection
  end
  root to: 'posts#index'
end
