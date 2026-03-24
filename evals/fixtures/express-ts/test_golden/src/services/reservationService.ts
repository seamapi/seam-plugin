import { Reservation } from "../models/types";
import { store, generateId, findUnit } from "../models/store";
import { Seam } from "seam";

const seam = new Seam({ apiKey: process.env.SEAM_API_KEY });

export async function createReservation(data: {
  guestName: string;
  guestEmail: string;
  unitId: string;
  checkIn: string;
  checkOut: string;
}): Promise<Reservation> {
  const unit = findUnit(data.unitId);
  if (!unit) {
    throw new Error(`Unit not found: ${data.unitId}`);
  }

  // Find existing guest by email or create a new one
  let guest = store.guests.find((g) => g.email === data.guestEmail);
  if (!guest) {
    guest = {
      id: generateId(),
      name: data.guestName,
      email: data.guestEmail,
    };
    store.guests.push(guest);
  }

  const reservation: Reservation = {
    id: generateId(),
    guestId: guest.id,
    unitId: data.unitId,
    checkIn: data.checkIn,
    checkOut: data.checkOut,
    status: "confirmed",
  };

  store.reservations.push(reservation);

  await seam.customers.push_data({
    customer_key: `pm_${reservation.unitId}`,
    user_identities: [{
      user_identity_key: `guest_${guest.id}`,
      name: guest.name,
      email_address: guest.email
    }],
    reservations: [{
      reservation_key: `res_${reservation.id}`,
      user_identity_key: `guest_${guest.id}`,
      starts_at: reservation.checkIn,
      ends_at: reservation.checkOut,
      space_keys: [reservation.unitId]
    }]
  });

  return reservation;
}

export async function updateReservation(
  id: string,
  data: { checkIn?: string; checkOut?: string }
): Promise<Reservation> {
  const reservation = store.reservations.find((r) => r.id === id);
  if (!reservation) {
    throw new Error(`Reservation not found: ${id}`);
  }

  if (data.checkIn !== undefined) {
    reservation.checkIn = data.checkIn;
  }
  if (data.checkOut !== undefined) {
    reservation.checkOut = data.checkOut;
  }

  const guest = store.guests.find((g) => g.id === reservation.guestId);

  await seam.customers.push_data({
    customer_key: `pm_${reservation.unitId}`,
    user_identities: guest ? [{
      user_identity_key: `guest_${guest.id}`,
      name: guest.name,
      email_address: guest.email
    }] : [],
    reservations: [{
      reservation_key: `res_${reservation.id}`,
      user_identity_key: `guest_${reservation.guestId}`,
      starts_at: reservation.checkIn,
      ends_at: reservation.checkOut,
      space_keys: [reservation.unitId]
    }]
  });

  return reservation;
}

export async function cancelReservation(id: string): Promise<Reservation> {
  const reservation = store.reservations.find((r) => r.id === id);
  if (!reservation) {
    throw new Error(`Reservation not found: ${id}`);
  }

  reservation.status = "cancelled";

  await seam.customers.delete_data({
    customer_key: `pm_${reservation.unitId}`,
    reservation_keys: [`res_${reservation.id}`],
    user_identity_keys: [`guest_${reservation.guestId}`]
  });

  return reservation;
}

export function getReservation(id: string): Reservation {
  const reservation = store.reservations.find((r) => r.id === id);
  if (!reservation) {
    throw new Error(`Reservation not found: ${id}`);
  }

  return reservation;
}
