class ReservationService
  class << self
    def create_reservation(data)
      unit = Store.find_unit(data[:unit_id])
      raise "Unit not found: #{data[:unit_id]}" unless unit

      # Find existing guest by email or create a new one
      guest = Store.guests.find { |g| g[:email] == data[:guest_email] }
      unless guest
        guest = {
          id: Store.generate_id,
          name: data[:guest_name],
          email: data[:guest_email]
        }
        Store.guests << guest
      end

      reservation = {
        id: Store.generate_id,
        guest_id: guest[:id],
        unit_id: data[:unit_id],
        property_id: data[:property_id],
        check_in: data[:check_in],
        check_out: data[:check_out],
        status: "confirmed"
      }

      Store.reservations << reservation
      reservation
    end

    def update_reservation(id, data)
      reservation = Store.reservations.find { |r| r[:id] == id }
      raise "Reservation not found: #{id}" unless reservation

      reservation[:check_in] = data[:check_in] if data[:check_in].present?
      reservation[:check_out] = data[:check_out] if data[:check_out].present?

      reservation
    end

    def cancel_reservation(id)
      reservation = Store.reservations.find { |r| r[:id] == id }
      raise "Reservation not found: #{id}" unless reservation

      reservation[:status] = "cancelled"
      reservation
    end

    def get_reservation(id)
      reservation = Store.reservations.find { |r| r[:id] == id }
      raise "Reservation not found: #{id}" unless reservation

      reservation
    end
  end
end
