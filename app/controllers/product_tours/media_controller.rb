# frozen_string_literal: true

module ProductTours
  class MediaController < ApplicationController
    def show
      post = Post.find(params[:id])
      allowed = ProductTours.admin?(request) || (ProductTours.enabled?(request) && post.published?)
      return head :forbidden unless allowed
      return head :not_found unless post.uploaded_video?

      redirect_to main_app.rails_blob_path(post.video, disposition: 'inline')
    end
  end
end
