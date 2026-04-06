from flask import Blueprint, jsonify, request

webhooks_bp = Blueprint("webhooks", __name__, url_prefix="/webhooks")


@webhooks_bp.route("/payments", methods=["POST"])
def payments():
    print("Received payment webhook:", request.json)
    return jsonify({"received": True}), 200
