import paho.mqtt.client as mqtt
import json
import uuid

BROKER = "localhost"
PORT = 1883

DEVICE_ID = "tablet_1"

COMMAND_TOPIC = f"cum/command/{DEVICE_ID}"
EVENT_TOPIC = f"cum/event/{DEVICE_ID}"


def make_id(message_id=None):
    return message_id or str(uuid.uuid4())


def publish_command(client, action, payload, message_id=None):
    command_id = make_id(message_id)
    client.publish(COMMAND_TOPIC, json.dumps({
        "id": command_id,
        "type": "command",
        "action": action,
        "payload": payload,
    }))
    return command_id


def publish_event(client, event_name, payload, message_id):
    client.publish(EVENT_TOPIC, json.dumps({
        "id": make_id(message_id),
        "type": "event",
        "event": event_name,
        "payload": payload,
    }))

def on_connect(client, userdata, flags, rc): 
    print("connected", rc)
    client.subscribe(EVENT_TOPIC)

def send_msg(client, text, message_id=None):
    publish_command(client, "msg", {"text": text}, message_id)

def send_ping(client, message_id=None):
    publish_command(client, "ping", {}, message_id)

def send_brightness(client, value, message_id=None):
    publish_command(client, "brightness", {"value": value}, message_id)

def return_msg(client, text, message_id):
    publish_event(client, "ack", {
        "text": f"received: {text}"
    }, message_id)
    
def on_message(client, userdata, msg):
    payload = msg.payload.decode()
    data = json.loads(payload)
    message_type = data.get("type")

    if message_type == "command":
        action = data.get("action")
        message_id = data.get("id")
        if action == 'msg':
            handle_msg(client, data, message_id)
        elif action == 'ping':
            handle_ping(client, data, message_id)
        elif action == 'brightness':
            handle_brightness(client, data, message_id)
    elif message_type == "event":
        handle_event(data)

def handle_msg(client, data, message_id):
    payload = data["payload"]["text"]
    return_msg(client, payload, message_id)

def handle_ping(client, data, message_id):
    print("ping received")
    publish_event(client, "pong", {}, message_id)

def handle_brightness(client, data, message_id):
    brightness = data["payload"]["value"]
    print("brightness: ", brightness)
    publish_event(client, "brightness_received", {"value": brightness}, message_id)

def handle_event(data):
    print("event:", data.get("event"), "id:", data.get("id"), "payload:", data.get("payload"))

client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

client.connect(BROKER, PORT, 60)
client.subscribe(COMMAND_TOPIC)

client.loop_start()

import time

time.sleep(2)
 
send_msg(client, "core has started")

while True:
    time.sleep(1)