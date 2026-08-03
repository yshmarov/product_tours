# frozen_string_literal: true

module ProductTours
  class PostsController < ApplicationController
    PER_PAGE = 50

    layout :product_tours_admin_layout
    before_action :require_admin
    before_action :set_post,
                  only: %i[show edit update destroy refresh_video_metadata add_translation publish unpublish]
    before_action :load_linkable_posts, only: %i[new create edit update]
    before_action :load_translations, only: :show

    def index
      @status = Post::STATUSES.include?(params[:status]) ? params[:status] : 'published'
      @query = params[:q].to_s.strip.presence
      @counts = Post.where(locale: default_locale).group(:status).count

      key_scope = Post.where(status: @status, locale: default_locale)
      @keys = key_scope.distinct.order(:key).pluck(:key)

      scope = posts_with_video.newest_first.where(status: @status, locale: default_locale)
      scope = scope.where('LOWER(key) LIKE ?', "%#{Post.sanitize_sql_like(@query.downcase)}%") if @query
      @page = [params[:page].to_i, 1].max
      @posts = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
      @more = @posts.size > PER_PAGE
      @posts = @posts.first(PER_PAGE)

      @selected_post = posts_with_video.find_by(id: params[:post_id]) if params[:post_id].present?
      load_translations if @selected_post
    end

    def show; end

    def new
      @post = Post.new(locale: default_locale)
    end

    def create
      @post = Post.new(post_attributes.merge(locale: default_locale))
      if @post.save
        redirect_to post_path(@post), notice: t('product_tours.dashboard.created', default: 'Tutorial created.')
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @post.update(post_attributes)
        remove_uploaded_video if remove_uploaded_video?
        redirect_to post_path(@post), notice: t('product_tours.dashboard.updated', default: 'Tutorial updated.')
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if default_locale_post?(@post) && translations_for(@post).where.not(id: @post.id).exists?
        redirect_to post_path(@post),
                    alert: t('product_tours.dashboard.delete_translations_first',
                             default: 'Delete this tutorial\'s translations before deleting the ' \
                                      'default-language tutorial.')
        return
      end

      @post.destroy!
      redirect_to posts_path,
                  notice: t('product_tours.dashboard.deleted', default: 'Tutorial deleted.'), status: :see_other
    end

    def add_translation
      locale = params[:locale].to_s
      unless available_locales.include?(locale) && locale != @post.locale
        redirect_to post_path(@post),
                    alert: t('product_tours.dashboard.translation_locale_invalid',
                             default: 'Choose another available language.')
        return
      end

      existing = Post.find_by(locale: locale, key: @post.key)
      if existing
        redirect_to post_path(existing),
                    notice: t('product_tours.dashboard.translation_exists',
                              default: 'That translation already exists.')
        return
      end

      source = translations_for(@post).find_by(locale: default_locale) || @post
      translation = source.dup
      translation.locale = locale
      translation.status = 'draft'
      if translation.action_post_key.present? &&
         !Post.exists?(locale: locale, key: translation.action_post_key)
        translation.action_post_key = nil
      end
      translation.save!
      if Post.description_supported? && source.description.present?
        translation.update!(description: source.description.body)
      end
      translation.video.attach(source.video.blob) if source.uploaded_video?

      redirect_to edit_post_path(translation),
                  notice: t('product_tours.dashboard.translation_added',
                            default: 'Translation added as a draft. Translate its content before publishing.')
    end

    def publish
      @post.update!(status: 'published')
      redirect_to post_path(@post), notice: t('product_tours.dashboard.published', default: 'Tutorial published.')
    end

    def unpublish
      @post.update!(status: 'draft')
      redirect_to post_path(@post),
                  notice: t('product_tours.dashboard.unpublished', default: 'Tutorial moved to drafts.')
    end

    def video_preview
      resolved = VideoResolver.resolve(params[:url])
      unless resolved
        render json: { error: t('product_tours.dashboard.video_invalid', default: 'Enter a supported video URL.') },
               status: :unprocessable_entity
        return
      end

      metadata = VideoMetadata.fetch(params[:url])
      render json: {
        kind: resolved.kind,
        provider: resolved.provider,
        url: resolved.url,
        title: metadata['provider_title'],
        thumbnail_url: metadata['thumbnail_url']
      }.compact
    end

    def refresh_video_metadata
      metadata = VideoMetadata.fetch(@post.video_url)
      if metadata.present?
        @post.update!(video_metadata: @post.video_metadata.to_h.merge(metadata))
        redirect_to edit_post_path(@post),
                    notice: t('product_tours.dashboard.metadata_updated', default: 'Video data refreshed.')
      else
        redirect_to edit_post_path(@post),
                    alert: t('product_tours.dashboard.metadata_failed',
                             default: 'Video data could not be fetched. The URL was not changed.')
      end
    end

    private

    def posts_with_video
      Post.video_upload_supported? ? Post.with_attached_video : Post.all
    end

    def set_post
      @post = Post.find(params[:id])
    end

    def post_params
      permitted = %i[key status title video_url action_label action_url action_post_key]
      permitted << :description if Post.description_supported?
      permitted << :video if Post.video_upload_supported?
      params.require(:post).permit(*permitted)
    end

    def post_attributes
      attributes = post_params
      attributes.delete(:key) if identity_locked?
      case params[:video_source]
      when 'url'
        attributes.delete(:video)
      when 'upload'
        attributes[:video_url] = nil
      end
      case params[:action_target]
      when 'close'
        attributes[:action_url] = nil
        attributes[:action_post_key] = nil
      when 'url'
        attributes[:action_post_key] = nil
      when 'post'
        attributes[:action_url] = nil
      end
      attributes
    end

    def load_linkable_posts
      @linkable_posts = Post.where.not(id: @post&.id).order(:locale, :title, :key)
                            .select(:id, :key, :locale, :status, :title)
      @identity_locked = identity_locked?
    end

    def load_translations
      post = @selected_post || @post
      @translations = translations_for(post).order(:locale).to_a
      @missing_translation_locales = available_locales - @translations.map(&:locale)
    end

    def translations_for(post)
      Post.where(key: post.key)
    end

    def available_locales
      (I18n.available_locales.map(&:to_s) + [default_locale]).uniq.sort
    end

    def default_locale
      I18n.default_locale.to_s
    end

    def default_locale_post?(post)
      post.locale == default_locale
    end

    def identity_locked?
      @post&.persisted? &&
        (!default_locale_post?(@post) || translations_for(@post).where.not(id: @post.id).exists?)
    end

    def remove_uploaded_video?
      params[:video_source] == 'url' && @post.uploaded_video?
    end

    def remove_uploaded_video
      @post.video.purge if @post.uploaded_video?
    end
  end
end
