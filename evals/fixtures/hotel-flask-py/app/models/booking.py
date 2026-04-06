from dataclasses import dataclass


@dataclass
class Guest:
    id: str
    name: str
    email: str
    phone: str


@dataclass
class Booking:
    id: str
    guest_id: str
    room_id: str
    check_in: str
    check_out: str
    status: str  # "confirmed" or "cancelled"
