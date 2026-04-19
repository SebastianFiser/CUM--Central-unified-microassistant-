from mqtt_client import publish_event
from mqtt_client import SENDER_ID


def route_message(client, data, logger=print):
    message_type = data.get("type")

    if message_type == "command":
        if data.get("sender_id") == SENDER_ID:
            return

        action = data.get("action")
        message_id = data.get("id")
        if action == "msg":
            handle_msg(client, data, message_id, logger)
        elif action == "ping":
            handle_ping(client, data, message_id, logger)
        elif action == "brightness":
            handle_brightness(client, data, message_id, logger)
        elif action == "register":
            handle_register(client, data, message_id, logger)
        elif action == "heartbeat":
            handle_heartbeat(client, data, message_id, logger)
        elif action == "status_request":
            handle_status_request(client, data, message_id, logger)
    elif message_type == "event":
        handle_event(data, logger)


def handle_msg(client, data, message_id, logger):
    payload = data["payload"]["text"]
    publish_event(client, "ack", {"text": f"received: {payload}"}, message_id)


def handle_ping(client, data, message_id, logger):
    logger("ping received")
    publish_event(client, "pong", {}, message_id)


def handle_brightness(client, data, message_id, logger):
    brightness = data["payload"]["value"]
    logger(f"brightness: {brightness}")
    publish_event(client, "brightness_received", {"value": brightness}, message_id)


def handle_event(data, logger):
    logger(f"event: {data.get('event')} id: {data.get('id')} payload: {data.get('payload')}")


def handle_register(client, data, message_id, logger):
    from registry import register_device
    payload = data["payload"]
    device_id = payload.get("device_id")
    meta = payload.get("meta", {})
    sender_id = data.get("sender_id")
    session_id = data.get("session_id") or payload.get("session_id", "")
    
    _, is_new_session = register_device(device_id, sender_id, session_id, meta)
    if is_new_session:
        logger(f"device registered: {device_id} session: {session_id}")
    else:
        logger(f"device refreshed: {device_id} session: {session_id}")
    publish_event(client, "device_registered", {"device_id": device_id}, message_id)

def handle_heartbeat(client, data, message_id, logger):
    from registry import heartbeat_device
    payload = data["payload"]
    device_id = payload.get("device_id")
    session_id = data.get("session_id") or payload.get("session_id", "")
    
    device = heartbeat_device(device_id, session_id)
    if device is None:
        logger(f"stale or unknown heartbeat ignored: {device_id} session: {session_id}")
        return

    logger(f"heartbeat: {device_id} session: {session_id}")
    publish_event(client, "heartbeat_ack", {"device_id": device_id}, message_id)

def handle_status_request(client, data, message_id, logger):
    from registry import get_device
    from mqtt_client import send_status_response
    payload = data["payload"]
    device_id = payload.get("device_id")
    
    device = get_device(device_id)
    if device:
        send_status_response(client, device_id, device["status"], device["last_seen"], message_id)
        logger(f"status sent: {device_id}")
