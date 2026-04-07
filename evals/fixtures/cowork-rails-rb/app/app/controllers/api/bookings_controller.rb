module Api
  class BookingsController < ApplicationController
    def create
      booking = BookingService.create_booking(booking_params)
      render json: { booking: booking }, status: :created
    end

    def show
      booking = BookingService.get_booking(params[:id])
      render json: { booking: booking }
    end

    def update
      booking = BookingService.update_booking(params[:id], booking_params)
      render json: { booking: booking }
    end

    def destroy
      booking = BookingService.cancel_booking(params[:id])
      render json: { booking: booking }
    end

    private

    def booking_params
      params.permit(:member_name, :member_email, :member_company, :room_id, :start_time, :end_time)
    end
  end
end
