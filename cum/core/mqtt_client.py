import json
import os
import uuid

from models import command_to_dict, event_to_dict


BROKER = os.getenv("CUM_BROKER", "localhost")
PORT = int(os.getenv("CUM_PORT", "1883"))
DEVICE_ID = "device1"
SENDER_ID = DEVICE_ID

COMMAND_TOPIC = f"cum/command/{DEVICE_ID}"
EVENT_TOPIC = f"cum/event/{DEVICE_ID}"

def publish(client, topic, payload):
    client.publish(topic, json.dumps(payload))
    print("PUBLISH:", topic, payload)

def make_id(message_id=None):
	return message_id or str(uuid.uuid4())


def publish_command(client, action, payload, message_id=None):
	command_id = make_id(message_id)
	client.publish(COMMAND_TOPIC, json.dumps(command_to_dict(command_id, action, payload, SENDER_ID)))
	return command_id


def publish_event(client, event_name, payload, message_id):
	client.publish(EVENT_TOPIC, json.dumps(event_to_dict(make_id(message_id), event_name, payload, SENDER_ID)))


def send_status_response(client, device_id, status, last_seen, message_id):
    from models import status_response_to_dict
    client.publish(EVENT_TOPIC, json.dumps(status_response_to_dict(
        make_id(message_id), device_id, status, last_seen, SENDER_ID
    )))
