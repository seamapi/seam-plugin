module Store
  @id_counter = 0

  @members = []

  @rooms = [
    { id: "room-a1", name: "Focus Room A1", capacity: 1, floor: 1 },
    { id: "room-b2", name: "Meeting Room B2", capacity: 6, floor: 2 },
    { id: "room-c3", name: "Board Room C3", capacity: 12, floor: 3 }
  ]

  @bookings = []

  class << self
    attr_accessor :members, :rooms, :bookings

    def generate_id
      @id_counter += 1
      "id-#{Time.now.to_i}-#{@id_counter}"
    end

    def find_room(id)
      @rooms.find { |r| r[:id] == id }
    end

    def find_member(id)
      @members.find { |m| m[:id] == id }
    end
  end
end
