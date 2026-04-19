def core_log(message):
    if _log_incoming.is_set():
        safe_log(message)
import json
import threading
import time
import sys
import readline

import paho.mqtt.client as mqtt

from mqtt_client import BROKER, COMMAND_TOPIC, EVENT_TOPIC, PORT
from router import route_message
from controller import ping_device, send_msg


PROMPT = "Enter command (type 'exit' to quit): "
_print_lock = threading.Lock()
_log_incoming = threading.Event()

# Výslovně zajistí, že logování je po startu vypnuté
_log_incoming.clear()
_log_incoming.clear()  # Logování vypnuto po startu

def on_connect(client, userdata, flags, rc): 
    safe_log(f"connected {rc}")
    client.subscribe(EVENT_TOPIC)

def on_message(client, userdata, msg):
    payload = msg.payload.decode()
    data = json.loads(payload)
    core_log(f"[INCOMING] {payload}")
    route_message(client, data, logger=core_log)

def check_devices_status():
    from registry import check_offline_devices, get_all_devices
    while True:
        time.sleep(5)  # každých 5 sekund
        offline_devices = check_offline_devices(timeout=15.0)
        if offline_devices:
            for device_id in offline_devices:
                safe_log(f"OFFLINE: {device_id}")
                # Zde se dá později přidat publish offline eventu
        
        # Status status
        all_devices = get_all_devices()
        online_count = sum(1 for d in all_devices.values() if d["status"] == "online")
        safe_log(f"[STATUS] Online devices: {online_count}/{len(all_devices)}")

def safe_log(message):
    with _print_lock:
        current_input = readline.get_line_buffer()
        sys.stdout.write("\r\033[K")
        sys.stdout.write(f"{message}\n")
        sys.stdout.write(f"{PROMPT}{current_input}")
        sys.stdout.flush()

def console():
    while True:
        command = input(PROMPT).strip()
        cmd_lower = command.lower()
        if cmd_lower == "exit":
            break
        elif cmd_lower.startswith("msg "):
            short_id, text = command.split(" ", 2)[1:]
            result = send_msg(client, short_id, text)
            if result:
                safe_log(f"Message sent to [{short_id}]: {text}")
            else:
                safe_log("error sending message")
        elif cmd_lower.startswith("ping "):
            # Mířený ping podle short_id přes controller
            short_id = command.split(" ", 1)[1].strip()
            result = ping_device(client, short_id)
            if result:
                safe_log(f"Targeted ping sent to [{short_id}]")
            else:
                safe_log(f"Device with short_id '{short_id}' not found")
        elif cmd_lower == "log on":
            _log_incoming.set()
            safe_log("Logging incoming messages: ON")
        elif cmd_lower == "log off":
            _log_incoming.clear()
            safe_log("Logging incoming messages: OFF")
        elif cmd_lower == "devices":
            from registry import get_all_devices
            devices = get_all_devices()
            if devices:
                for device_id, info in devices.items():
                    meta = info["meta"]
                    short_id = meta.get("short_id", "----")
                    name = meta.get("name")
                    # Pokud je name stejný jako short_id, použij device_id
                    if not name or name == short_id:
                        name = device_id
                    safe_log(f"{device_id} [{short_id}] - Status: {info['status']}, Last seen: {info['last_seen']}, Name: {name}")
            else:
                safe_log("No devices registered")
        elif cmd_lower.startswith("status "):
            device_id = command.split(" ", 1)[1]
            from registry import get_device
            device = get_device(device_id)
            if device:
                meta = device["meta"]
                short_id = meta.get("short_id", "----")
                # Pokud je name stejný jako short_id, použij device_id
                name = meta.get("name")
                if not name or name == short_id:
                    name = device_id
                safe_log(f"Status: {device['status']}, Last seen: {device['last_seen']}, Name: {name}, ShortID: {short_id}")
            else:
                safe_log("Device not found")
        else:
            safe_log("Unknown command")

client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

client.connect(BROKER, PORT, 60)
client.subscribe(COMMAND_TOPIC)

client.loop_start()

time.sleep(2)
status_thread = threading.Thread(target=check_devices_status, daemon=True)
status_thread.start()
console()