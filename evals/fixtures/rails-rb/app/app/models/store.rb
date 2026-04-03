module Store
  @id_counter = 0

  @guests = []

  @properties = [
    { id: "prop-1", name: "Sunset Rentals", address: "123 Sunset Blvd, Los Angeles, CA 90028" }
  ]

  @units = [
    { id: "unit-101", property_id: "prop-1", name: "Unit 101" },
    { id: "unit-202", property_id: "prop-1", name: "Unit 202" }
  ]

  @reservations = []

  class << self
    attr_accessor :guests, :properties, :units, :reservations

    def generate_id
      @id_counter += 1
      "id-#{Time.now.to_i}-#{@id_counter}"
    end

    def find_unit(id)
      @units.find { |u| u[:id] == id }
    end

    def find_guest(id)
      @guests.find { |g| g[:id] == id }
    end
  end
end
