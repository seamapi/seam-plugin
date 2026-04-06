import uuid

from models.booking import Booking, Guest
from models.room import Room

# In-memory data store
rooms = [
    Room(id="room-101", number="101", floor=1, type="standard"),
    Room(id="room-205", number="205", floor=2, type="suite"),
    Room(id="room-ph1", number="PH1", floor=3, type="penthouse"),
]

guests: list[Guest] = []

bookings: list[Booking] = []


def generate_id() -> str:
    return str(uuid.uuid4())


def find_room(room_id: str) -> Room | None:
    return next((r for r in rooms if r.id == room_id), None)


def find_guest(guest_id: str) -> Guest | None:
    return next((g for g in guests if g.id == guest_id), None)
