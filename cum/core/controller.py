
from registry import get_all_devices, get_device
from mqtt_client import publish, COMMAND_TOPIC, SENDER_ID
from models import command_to_dict
import uuid

def resolve_device_id(short_id):
    for device_id, info in get_all_devices().items():
        if info["meta"].get("short_id") == short_id:
            return device_id
    return None

def generate_msg_id(message_id=None):
    	return message_id or str(uuid.uuid4())

def ping_device(client, short_id):
    device_id = resolve_device_id(short_id)
    if not device_id:
        return False
    device = get_device(device_id)
    session_id = device.get("session_id") if device else ""
    payload = {"device_id": device_id, "session_id": session_id}
    # Build the full command dict here
    command_id = generate_msg_id()
    command_msg = command_to_dict(command_id, "ping", payload, SENDER_ID)
    publish(client, COMMAND_TOPIC, command_msg)
    return True

def send_msg(client, short_id, text):
    device_id = resolve_device_id(short_id)
    if not device_id:
        return False
    device = get_device(device_id)
    session_id = device.get("session_id") if device else ""
    payload = {"device_id": device_id, "session_id": session_id, "text": text}
    command_id = generate_msg_id()
    command_msg = command_to_dict(command_id, "msg", payload, SENDER_ID)
    publish(client, COMMAND_TOPIC, command_msg)
    return True