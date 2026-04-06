from flask import Blueprint, jsonify, request

from services.booking_service import (
    cancel_booking,
    create_booking,
    get_booking,
    update_booking,
)

bookings_bp = Blueprint("bookings", __name__, url_prefix="/api/bookings")


@bookings_bp.route("", methods=["POST"])
def create():
    try:
        booking = create_booking(request.json)
        return jsonify({"booking": booking}), 201
    except ValueError as e:
        return jsonify({"error": str(e)}), 400


@bookings_bp.route("/<booking_id>", methods=["PUT"])
def update(booking_id):
    try:
        booking = update_booking(booking_id, request.json)
        return jsonify({"booking": booking}), 200
    except LookupError as e:
        return jsonify({"error": str(e)}), 404


@bookings_bp.route("/<booking_id>", methods=["DELETE"])
def cancel(booking_id):
    try:
        booking = cancel_booking(booking_id)
        return jsonify({"booking": booking}), 200
    except LookupError as e:
        return jsonify({"error": str(e)}), 404


@bookings_bp.route("/<booking_id>", methods=["GET"])
def get(booking_id):
    try:
        booking = get_booking(booking_id)
        return jsonify({"booking": booking}), 200
    except LookupError as e:
        return jsonify({"error": str(e)}), 404
