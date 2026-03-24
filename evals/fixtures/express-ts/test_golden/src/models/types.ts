export interface Guest {
  id: string;
  name: string;
  email: string;
}

export interface Property {
  id: string;
  name: string;
  address: string;
}

export interface Unit {
  id: string;
  propertyId: string;
  name: string;
}

export interface Reservation {
  id: string;
  guestId: string;
  unitId: string;
  checkIn: string;
  checkOut: string;
  status: "confirmed" | "cancelled";
}
