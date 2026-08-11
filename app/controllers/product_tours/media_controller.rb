# frozen_string_literal: true

module ProductTours
  class MediaController < ApplicationController
    include ActiveStorage::Streaming if defined?(::ActiveStorage::Streaming)

    def show
      tour = Tour.find(params[:id])
      allowed = ProductTours.admin?(request) || (ProductTours.enabled?(request) && tour.published?)
      return head :forbidden unless allowed
      return head :not_found unless tour.uploaded_video?

      stream(tour.video.blob)
    end

    private

    # Keep the browser on the authorized engine URL while retaining the byte
    # range behavior video playback and seeking need. Active Storage's own
    # streaming concern supports both full and ranged responses without a
    # permanent signed blob URL escaping this controller's gate.
    def stream(blob)
      response.headers['Cache-Control'] = 'private, no-store'
      if request.headers['Range'].present?
        send_blob_byte_range_data blob, request.headers['Range']
      else
        response.headers['Accept-Ranges'] = 'bytes'
        response.headers['Content-Length'] = blob.byte_size.to_s
        send_blob_stream blob, disposition: 'inline'
      end
    end
  end
end
