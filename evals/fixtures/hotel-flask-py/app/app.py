import os

from flask import Flask, jsonify

from blueprints.bookings import bookings_bp
from blueprints.webhooks import webhooks_bp

app = Flask(__name__)

app.register_blueprint(bookings_bp)
app.register_blueprint(webhooks_bp)


@app.route("/health")
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
