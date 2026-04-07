class BookingService
  class << self
    def create_booking(data)
      room = Store.find_room(data[:room_id])
      raise "Room not found: #{data[:room_id]}" unless room

      # Find existing member by email or create a new one
      member = Store.members.find { |m| m[:email] == data[:member_email] }
      unless member
        member = {
          id: Store.generate_id,
          name: data[:member_name],
          email: data[:member_email],
          company: data[:member_company]
        }
        Store.members << member
      end

      booking = {
        id: Store.generate_id,
        member_id: member[:id],
        room_id: data[:room_id],
        start_time: data[:start_time],
        end_time: data[:end_time],
        status: "active"
      }

      Store.bookings << booking
      booking
    end

    def update_booking(id, data)
      booking = Store.bookings.find { |b| b[:id] == id }
      raise "Booking not found: #{id}" unless booking

      booking[:start_time] = data[:start_time] if data[:start_time].present?
      booking[:end_time] = data[:end_time] if data[:end_time].present?

      booking
    end

    def cancel_booking(id)
      booking = Store.bookings.find { |b| b[:id] == id }
      raise "Booking not found: #{id}" unless booking

      booking[:status] = "cancelled"
      booking
    end

    def get_booking(id)
      booking = Store.bookings.find { |b| b[:id] == id }
      raise "Booking not found: #{id}" unless booking

      booking
    end
  end
end
