import logging

from flask import Flask, request
from flask.json import jsonify

app = Flask(__name__)
handler = None


@app.route("/", methods=["POST"])
def handle_request():
    payload = request.get_json(force=True)
    result = handler(payload, {})

    return (
        jsonify(result),
        200,
    )


class ModelServer:
    def __init__(self, port, handler):
        self.port = port
        self.handler = handler

    def start(self):
        global handler
        handler = self.handler
        app.run(host="0.0.0.0", debug=True, use_reloader=False, port=self.port)
        app.logger.setLevel(logging.DEBUG)
