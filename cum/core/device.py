import json
import time
import uuid
import argparse
import socket
import paho.mqtt.client as mqtt
from pathlib import Path

BROKER = "192.168.0.116"
PORT = 1883
HEARTBEAT_INTERVAL_SECONDS = 5
DEVICE_ID_FILE = Path(__file__).with_name("device_id.txt")
SESSION_ID = str(uuid.uuid4())[:8]

def generate_device_id(prefix="device"):
    host = socket.gethostname().split(".")[0]
    return f"{prefix}-{host}-{uuid.uuid4().hex[:8]}"

def load_or_create_device_id(path=DEVICE_ID_FILE, prefix="device"):
    if path.exists():
        stored = path.read_text(encoding="utf-8").strip()
        if stored:
            return stored
    
    host = socket.gethostname().split(".")[0]
    new_id = f"{prefix}-{host}-{uuid.uuid4().hex[:8]}"
    path.write_text(new_id + "\n", encoding="utf-8")
    return new_id

def build_command_topic(core_id):
    return f"cum/command/{core_id}"


def build_event_topic(core_id):
    return f"cum/event/{core_id}"


def publish_register(client, command_topic, device_id):
    client.publish(command_topic, json.dumps({
        "id": str(uuid.uuid4()),
        "sender_id": device_id,
        "session_id": SESSION_ID,
        "type": "command",
        "action": "register",
        "payload": {
            "device_id": device_id,
            "meta": {
                "kind": "device.py"
            }
        }
    }))


def publish_heartbeat(client, command_topic, device_id):
    client.publish(command_topic, json.dumps({
        "id": str(uuid.uuid4()),
        "sender_id": device_id,
        "session_id": SESSION_ID,
        "type": "command",
        "action": "heartbeat",
        "payload": {
            "device_id": device_id
        }
    }))


def publish_pong(client, event_topic, device_id, message_id):
    client.publish(event_topic, json.dumps({
        "id": message_id,
        "sender_id": device_id,
        "session_id": SESSION_ID,
        "type": "event",
        "event": "pong",
        "payload": {}
    }))


def main(device_id, core_id, broker, port):
    command_topic = build_command_topic(core_id)
    event_topic = build_event_topic(core_id)

    def on_connect(client, userdata, flags, rc):
        print(f"[{device_id}] connected rc={rc} session={SESSION_ID}")
        client.subscribe(command_topic)
        publish_register(client, command_topic, device_id)
        print(f"[{device_id}] sent register")

    def on_message(client, userdata, msg):
        print("RAW ONCOMING:", msg.payload.decode())
        data = json.loads(msg.payload.decode())
        if data.get("sender_id") == device_id:
            return

        if data.get("type") == "command" and data.get("action") == "ping":
            message_id = data.get("id")
            print(f"[{device_id}] ping received id={message_id}")
            publish_pong(client, event_topic, device_id, message_id)
            print(f"[{device_id}] pong sent id={message_id}")

    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(broker, port, 60)
    client.loop_start()

    try:
        while True:
            publish_heartbeat(client, command_topic, device_id)
            time.sleep(HEARTBEAT_INTERVAL_SECONDS)
    except KeyboardInterrupt:
        print("stopping device")
    finally:
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Simple MQTT device simulator")
    parser.add_argument("--device-id", default=None, help="Unique device id (if omitted, generated automatically)")
    parser.add_argument("--core-id", default="device1", help="Core topic id")
    parser.add_argument("--broker", default=BROKER, help="MQTT broker host")
    parser.add_argument("--port", type=int, default=PORT, help="MQTT broker port")
    args = parser.parse_args()

    if not args.device_id:
        args.device_id = load_or_create_device_id()
        print(f"loaded device_id: {args.device_id}")
    else:
        DEVICE_ID_FILE.write_text(args.device_id + "\n", encoding="utf-8")

    main(args.device_id, args.core_id, args.broker, args.port)
