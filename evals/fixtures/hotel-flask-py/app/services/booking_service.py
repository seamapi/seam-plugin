from models import store
from models.booking import Booking, Guest


def _booking_to_dict(b: Booking) -> dict:
    return {
        "id": b.id,
        "guest_id": b.guest_id,
        "room_id": b.room_id,
        "check_in": b.check_in,
        "check_out": b.check_out,
        "status": b.status,
    }


def create_booking(data: dict) -> dict:
    room_id = data.get("room_id")
    room = store.find_room(room_id)
    if not room:
        raise ValueError(f"Room {room_id} not found")

    guest_email = data.get("guest_email")
    guest_name = data.get("guest_name")
    guest_phone = data.get("guest_phone", "")

    # Find existing guest by email or create new one
    guest = next((g for g in store.guests if g.email == guest_email), None)
    if not guest:
        guest = Guest(
            id=store.generate_id(),
            name=guest_name,
            email=guest_email,
            phone=guest_phone,
        )
        store.guests.append(guest)

    booking = Booking(
        id=store.generate_id(),
        guest_id=guest.id,
        room_id=room_id,
        check_in=data.get("check_in"),
        check_out=data.get("check_out"),
        status="confirmed",
    )
    store.bookings.append(booking)

    return _booking_to_dict(booking)


def update_booking(booking_id: str, data: dict) -> dict:
    booking = next((b for b in store.bookings if b.id == booking_id), None)
    if not booking:
        raise LookupError(f"Booking {booking_id} not found")

    if "check_in" in data:
        booking.check_in = data["check_in"]
    if "check_out" in data:
        booking.check_out = data["check_out"]

    return _booking_to_dict(booking)


def cancel_booking(booking_id: str) -> dict:
    booking = next((b for b in store.bookings if b.id == booking_id), None)
    if not booking:
        raise LookupError(f"Booking {booking_id} not found")

    booking.status = "cancelled"

    return _booking_to_dict(booking)


def get_booking(booking_id: str) -> dict:
    booking = next((b for b in store.bookings if b.id == booking_id), None)
    if not booking:
        raise LookupError(f"Booking {booking_id} not found")

    return _booking_to_dict(booking)
