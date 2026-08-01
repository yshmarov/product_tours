# frozen_string_literal: true

module ProductTours
  class PostsController < ApplicationController
    PER_PAGE = 50

    layout :product_tours_admin_layout
    before_action :require_admin
    before_action :set_post, only: %i[show edit update destroy refresh_video_metadata]

    def index
      @status = Post::STATUSES.include?(params[:status]) ? params[:status] : 'published'
      @locale = params[:locale].to_s.strip.presence
      @query = params[:q].to_s.strip.presence
      @counts = Post.group(:status).count

      key_scope = Post.where(status: @status)
      key_scope = key_scope.where(locale: @locale) if @locale
      @keys = key_scope.distinct.order(:key).pluck(:key)

      scope = posts_with_video.newest_first.where(status: @status)
      scope = scope.where(locale: @locale) if @locale
      scope = scope.where('LOWER(key) LIKE ?', "%#{Post.sanitize_sql_like(@query.downcase)}%") if @query
      @page = [params[:page].to_i, 1].max
      @posts = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
      @more = @posts.size > PER_PAGE
      @posts = @posts.first(PER_PAGE)

      @locales = Post.distinct.order(:locale).pluck(:locale)
      @selected_post = posts_with_video.find_by(id: params[:post_id]) if params[:post_id].present?
    end

    def show; end

    def new
      @post = Post.new(locale: current_product_tours_locale)
    end

    def create
      @post = Post.new(post_params)
      if @post.save
        redirect_to post_path(@post), notice: t('product_tours.dashboard.created', default: 'Post created.')
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @post.update(post_params)
        remove_video if remove_video?
        redirect_to post_path(@post), notice: t('product_tours.dashboard.updated', default: 'Post updated.')
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @post.destroy!
      redirect_to posts_path, notice: t('product_tours.dashboard.deleted', default: 'Post deleted.'), status: :see_other
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
      permitted = %i[key locale status title video_url action_label action_url]
      permitted << :description if Post.description_supported?
      permitted << :video if Post.video_upload_supported?
      params.require(:post).permit(*permitted)
    end

    def remove_video?
      params.dig(:post, :remove_video) == '1' && params.dig(:post, :video).blank?
    end

    def remove_video
      @post.video.purge if @post.uploaded_video?
    end
  end
end
