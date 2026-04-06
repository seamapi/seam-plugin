export interface Guest {
  id: string;
  name: string;
  email: string;
  phone: string;
}

export interface Room {
  id: string;
  number: string;
  floor: number;
  type: "standard" | "suite" | "penthouse";
}

export interface Booking {
  id: string;
  guestId: string;
  roomId: string;
  checkIn: string;
  checkOut: string;
  status: "confirmed" | "cancelled";
}
