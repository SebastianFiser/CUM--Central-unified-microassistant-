from mqtt_client import publish_event
from mqtt_client import SENDER_ID


def route_message(client, data):
    message_type = data.get("type")

    if message_type == "command":
        if data.get("sender_id") == SENDER_ID:
            return

        action = data.get("action")
        message_id = data.get("id")
        if action == "msg":
            handle_msg(client, data, message_id)
        elif action == "ping":
            handle_ping(client, data, message_id)
        elif action == "brightness":
            handle_brightness(client, data, message_id)
        elif action == "register":
            handle_register(client, data, message_id)
        elif action == "heartbeat":
            handle_heartbeat(client, data, message_id)
        elif action == "status_request":
            handle_status_request(client, data, message_id)
    elif message_type == "event":
        handle_event(data)


def handle_msg(client, data, message_id):
	payload = data["payload"]["text"]
	publish_event(client, "ack", {"text": f"received: {payload}"}, message_id)


def handle_ping(client, data, message_id):
	print("ping received")
	publish_event(client, "pong", {}, message_id)


def handle_brightness(client, data, message_id):
	brightness = data["payload"]["value"]
	print("brightness: ", brightness)
	publish_event(client, "brightness_received", {"value": brightness}, message_id)


def handle_event(data):
	print("event:", data.get("event"), "id:", data.get("id"), "payload:", data.get("payload"))


def handle_register(client, data, message_id):
    from registry import register_device
    payload = data["payload"]
    device_id = payload.get("device_id")
    meta = payload.get("meta", {})
    sender_id = data.get("sender_id")
    
    register_device(device_id, sender_id, meta)
    print(f"device registered: {device_id}")
    publish_event(client, "device_registered", {"device_id": device_id}, message_id)

def handle_heartbeat(client, data, message_id):
    from registry import heartbeat_device
    payload = data["payload"]
    device_id = payload.get("device_id")
    
    heartbeat_device(device_id)
    print(f"heartbeat: {device_id}")
    publish_event(client, "heartbeat_ack", {"device_id": device_id}, message_id)

def handle_status_request(client, data, message_id):
    from registry import get_device
    from mqtt_client import send_status_response
    payload = data["payload"]
    device_id = payload.get("device_id")
    
    device = get_device(device_id)
    if device:
        send_status_response(client, device_id, device["status"], device["last_seen"], message_id)
        print(f"status sent: {device_id}")
