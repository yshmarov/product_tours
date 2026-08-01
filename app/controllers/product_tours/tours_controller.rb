# frozen_string_literal: true

module ProductTours
  class ToursController < ApplicationController
    SIGNALS = %w[viewed dismissed completed].freeze

    if respond_to?(:rate_limit) && ProductTours.config.rate_limit
      rate_limit(**ProductTours.config.rate_limit, only: %i[resolve signal], with: -> { render_rate_limited })
    end

    def resolve
      key = params[:key].to_s
      return handle_unresolved_trigger(key, :disabled) unless ProductTours.enabled?(request)
      return handle_unresolved_trigger(key, :invalid_key) unless key.match?(Post::KEY_FORMAT)

      post = Post.find_by(locale: current_product_tours_locale, key: key)
      return handle_unresolved_trigger(key, :missing) unless post
      return handle_unresolved_trigger(key, :unpublished) unless post.published?

      render json: post_payload(post)
    end

    def signal
      return head :forbidden unless ProductTours.enabled?(request)

      action = params[:event_action].to_s
      return head :unprocessable_entity unless SIGNALS.include?(action)

      post = Post.published.find_by(locale: current_product_tours_locale, key: params[:key].to_s)
      return head :not_found unless post

      payload = user_context.merge(
        post_id: post.id,
        key: post.key,
        locale: post.locale,
        tenant: current_product_tours_tenant,
        visitor_token: ensure_visitor_token,
        page_url: clean_page_url(params[:page_url]),
        source: params[:source].to_s.presence,
        metadata: signal_metadata
      )
      ActiveSupport::Notifications.instrument("product_tours.#{action}", payload)
      head :no_content
    end

    private

    def post_payload(post)
      video = post.resolved_video
      video[:url] = media_path(post) if video&.dig(:kind) == 'upload'
      {
        key: post.key,
        locale: post.locale,
        title: post.title,
        descriptionHtml: description_html(post),
        video: video,
        action: {
          label: post.action_label.presence || I18n.t(:done, scope: :product_tours, default: 'Done'),
          url: post.action_url.presence
        }
      }
    end

    def description_html(post)
      return unless Post.description_supported? && post.description.present?

      post.description.body.to_s
    end

    def signal_metadata
      value = params[:metadata]
      return {} unless value.respond_to?(:permit)

      value.permit(:duration, :progress).to_h
    end
  end
end
