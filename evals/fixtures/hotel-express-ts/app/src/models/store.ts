import { Guest, Room, Booking } from "./types";

let idCounter = 0;

export function generateId(): string {
  idCounter++;
  return `id-${Date.now()}-${idCounter}`;
}

export const store = {
  guests: [] as Guest[],
  rooms: [
    { id: "room-101", number: "101", floor: 1, type: "standard" },
    { id: "room-205", number: "205", floor: 2, type: "suite" },
    { id: "room-ph1", number: "PH1", floor: 3, type: "penthouse" },
  ] as Room[],
  bookings: [] as Booking[],
};

export function findRoom(id: string): Room | undefined {
  return store.rooms.find((r) => r.id === id);
}

export function findGuest(id: string): Guest | undefined {
  return store.guests.find((g) => g.id === id);
}
