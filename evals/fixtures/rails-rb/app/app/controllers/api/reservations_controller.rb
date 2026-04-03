module Api
  class ReservationsController < ApplicationController
    def create
      reservation = ReservationService.create_reservation(reservation_params)
      render json: { reservation: reservation }, status: :created
    end

    def show
      reservation = ReservationService.get_reservation(params[:id])
      render json: { reservation: reservation }
    end

    def update
      reservation = ReservationService.update_reservation(params[:id], reservation_params)
      render json: { reservation: reservation }
    end

    def destroy
      reservation = ReservationService.cancel_reservation(params[:id])
      render json: { reservation: reservation }
    end

    private

    def reservation_params
      params.permit(:guest_name, :guest_email, :property_id, :unit_id, :check_in, :check_out)
    end
  end
end
