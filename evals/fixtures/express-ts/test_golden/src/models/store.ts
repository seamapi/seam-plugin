import { Guest, Property, Unit, Reservation } from "./types";

let idCounter = 0;

export function generateId(): string {
  idCounter++;
  return `id-${Date.now()}-${idCounter}`;
}

export const store = {
  guests: [] as Guest[],
  properties: [
    {
      id: "prop-1",
      name: "Sunset Rentals",
      address: "123 Sunset Blvd, Los Angeles, CA 90028",
    },
  ] as Property[],
  units: [
    { id: "unit-101", propertyId: "prop-1", name: "Unit 101" },
    { id: "unit-202", propertyId: "prop-1", name: "Unit 202" },
  ] as Unit[],
  reservations: [] as Reservation[],
};

export function findUnit(id: string): Unit | undefined {
  return store.units.find((u) => u.id === id);
}

export function findGuest(id: string): Guest | undefined {
  return store.guests.find((g) => g.id === id);
}
