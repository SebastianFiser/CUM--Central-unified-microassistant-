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
        elif action == "console_exec":
            handle_console_exec(client, data, message_id, logger)
        elif action == "list_devices":
            handle_list_devices(client, data, message_id, logger)
    elif message_type == "event":
        handle_event(data, logger)


def handle_msg(client, data, message_id, logger):
    payload = data["payload"]["text"]
    publish_event(client, "ack", {"text": f"received: {payload}"}, message_id)


def handle_ping(client, data, message_id, logger):
    logger("ping received, replying with pong")
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
    
    device, is_new_session = register_device(device_id, sender_id, session_id, meta)
    if is_new_session:
        logger(f"device registered: {device_id} session: {session_id}")
    else:
        logger(f"device refreshed: {device_id} session: {session_id}")
    # include short_id in the device_registered event so clients can learn the mapping
    try:
        short_id = device.meta.get("short_id") if device and hasattr(device, 'meta') else None
    except Exception:
        short_id = None
    payload = {"device_id": device_id}
    if short_id:
        payload["short_id"] = short_id
    publish_event(client, "device_registered", payload, message_id)

def handle_heartbeat(client, data, message_id, logger):
    from registry import heartbeat_device
    payload = data["payload"]
    device_id = payload.get("device_id")
    session_id = data.get("session_id") or payload.get("session_id", "")
    
    device = heartbeat_device(device_id, session_id)
    if device is None:
        # Try to find a registered device by sender_id mapping and accept heartbeat
        from registry import find_device_id_by_sender
        sender = data.get("sender_id")
        if sender:
            mapped = find_device_id_by_sender(sender)
            if mapped:
                device = heartbeat_device(mapped, session_id)
                if device is not None:
                    logger(f"heartbeat accepted via sender mapping: {mapped} (sender: {sender}) session: {session_id}")
                    try:
                        short_id = device.meta.get("short_id") if device and hasattr(device, 'meta') else None
                    except Exception:
                        short_id = None
                    payload = {"device_id": mapped}
                    if short_id:
                        payload["short_id"] = short_id
                    publish_event(client, "heartbeat_ack", payload, message_id)
                    return

        logger(f"stale or unknown heartbeat ignored: {device_id} session: {session_id}")
        return

    logger(f"heartbeat: {device_id} session: {session_id}")
    try:
        short_id = device.meta.get("short_id") if device and hasattr(device, 'meta') else None
    except Exception:
        short_id = None
    payload = {"device_id": device_id}
    if short_id:
        payload["short_id"] = short_id
    publish_event(client, "heartbeat_ack", payload, message_id)

def handle_status_request(client, data, message_id, logger):
    from registry import get_device
    from mqtt_client import send_status_response
    payload = data["payload"]
    device_id = payload.get("device_id")
    
    device = get_device(device_id)
    if device:
        send_status_response(client, device_id, device["status"], device["last_seen"], message_id)
        logger(f"status sent: {device_id}")


def handle_list_devices(client, data, message_id, logger):
    from registry import get_all_devices
    devices = get_all_devices()
    # devices is a mapping device_id -> dict including meta.short_id
    publish_event(client, "devices_list", devices, message_id)
    logger("devices_list published")


def handle_console_exec(client, data, message_id, logger):
    from controller import ping_device, send_msg, send_brightness, send_register, send_heartbeat, send_status_request, resolve_device_id
    payload = data.get('payload', {}) or {}
    text = (payload.get('text') or '').strip()
    if not text:
        publish_event(client, 'ack', {'text': 'empty command'}, message_id)
        return

    cmd_lower = text.lower()
    try:
        if cmd_lower.startswith('brightness '):
            parts = text.split(' ')
            if len(parts) >= 3:
                short_id = parts[1]
                try:
                    value = int(parts[2])
                except ValueError:
                    publish_event(client, 'ack', {'text': 'invalid brightness value'}, message_id)
                    return
                ok = send_brightness(client, short_id, value)
                publish_event(client, 'ack', {'text': f'brightness sent to [{short_id}] = {value}' if ok else 'error'}, message_id)
                return
        elif cmd_lower.startswith('msg '):
            parts = text.split(' ')
            if len(parts) >= 3:
                short_id = parts[1]
                msg = ' '.join(parts[2:])
                ok = send_msg(client, short_id, msg)
                publish_event(client, 'ack', {'text': f'message sent to [{short_id}]' if ok else 'error'}, message_id)
                return
        elif cmd_lower.startswith('ping '):
            parts = text.split(' ')
            if len(parts) >= 2:
                short_id = parts[1]
                ok = ping_device(client, short_id)
                publish_event(client, 'ack', {'text': f'ping sent to [{short_id}]' if ok else f"device {short_id} not found"}, message_id)
                return
        elif cmd_lower.startswith('register '):
            parts = text.split(' ')
            if len(parts) >= 2:
                short_id = parts[1]
                ok = send_register(client, short_id)
                publish_event(client, 'ack', {'text': f'register sent to [{short_id}]' if ok else 'error'}, message_id)
                return
        elif cmd_lower.startswith('heartbeat '):
            parts = text.split(' ')
            if len(parts) >= 2:
                short_id = parts[1]
                ok = send_heartbeat(client, short_id)
                publish_event(client, 'ack', {'text': f'heartbeat sent to [{short_id}]' if ok else 'error'}, message_id)
                return
        elif cmd_lower.startswith('status '):
            parts = text.split(' ')
            if len(parts) >= 2:
                short_id = parts[1]
                ok = resolve_device_id(short_id)
                if ok:
                    # send status request via controller
                    send_status_request(client, short_id)
                    publish_event(client, 'ack', {'text': f'status requested for [{short_id}]'}, message_id)
                else:
                    publish_event(client, 'ack', {'text': f'device {short_id} not found'}, message_id)
                return
        elif cmd_lower in ('devices', 'list'):
            handle_list_devices(client, data, message_id, logger)
            publish_event(client, 'ack', {'text': 'devices_list published'}, message_id)
            return
    except Exception as e:
        logger(f'console_exec error: {e}')
        publish_event(client, 'ack', {'text': f'error: {e}'}, message_id)
        return

    publish_event(client, 'ack', {'text': 'unknown command'}, message_id)
