class WebhooksController < ApplicationController
  def payments
    Rails.logger.info("Received payment webhook: #{request.raw_post}")
    render json: { received: true }
  end
end
