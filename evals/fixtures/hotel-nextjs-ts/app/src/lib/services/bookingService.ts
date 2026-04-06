import { Booking } from "../models/types";
import { store, generateId, findRoom } from "../models/store";

export function createBooking(data: {
  guestName: string;
  guestEmail: string;
  guestPhone: string;
  roomId: string;
  checkIn: string;
  checkOut: string;
}): Booking {
  const room = findRoom(data.roomId);
  if (!room) {
    throw new Error(`Room not found: ${data.roomId}`);
  }

  // Find existing guest by email or create a new one
  let guest = store.guests.find((g) => g.email === data.guestEmail);
  if (!guest) {
    guest = {
      id: generateId(),
      name: data.guestName,
      email: data.guestEmail,
      phone: data.guestPhone,
    };
    store.guests.push(guest);
  }

  const booking: Booking = {
    id: generateId(),
    guestId: guest.id,
    roomId: data.roomId,
    checkIn: data.checkIn,
    checkOut: data.checkOut,
    status: "confirmed",
  };

  store.bookings.push(booking);
  return booking;
}

export function updateBooking(
  id: string,
  data: { checkIn?: string; checkOut?: string }
): Booking {
  const booking = store.bookings.find((b) => b.id === id);
  if (!booking) {
    throw new Error(`Booking not found: ${id}`);
  }

  if (data.checkIn !== undefined) {
    booking.checkIn = data.checkIn;
  }
  if (data.checkOut !== undefined) {
    booking.checkOut = data.checkOut;
  }

  return booking;
}

export function cancelBooking(id: string): Booking {
  const booking = store.bookings.find((b) => b.id === id);
  if (!booking) {
    throw new Error(`Booking not found: ${id}`);
  }

  booking.status = "cancelled";
  return booking;
}

export function getBooking(id: string): Booking {
  const booking = store.bookings.find((b) => b.id === id);
  if (!booking) {
    throw new Error(`Booking not found: ${id}`);
  }

  return booking;
}
