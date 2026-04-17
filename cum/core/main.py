import json
import time

import paho.mqtt.client as mqtt

from mqtt_client import BROKER, COMMAND_TOPIC, EVENT_TOPIC, PORT, send_msg
from router import route_message

def on_connect(client, userdata, flags, rc): 
    print("connected", rc)
    client.subscribe(EVENT_TOPIC)

def on_message(client, userdata, msg):
    payload = msg.payload.decode()
    data = json.loads(payload)
    route_message(client, data)

def check_devices_status():
    from registry import check_offline_devices, get_all_devices
    while True:
        time.sleep(5)  # každých 5 sekund
        offline_devices = check_offline_devices(timeout=15.0)
        if offline_devices:
            for device_id in offline_devices:
                print(f"OFFLINE: {device_id}")
                # Zde se dá později přidat publish offline eventu
        
        # Status status
        all_devices = get_all_devices()
        online_count = sum(1 for d in all_devices.values() if d["status"] == "online")
        print(f"[STATUS] Online devices: {online_count}/{len(all_devices)}")

client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

client.connect(BROKER, PORT, 60)
client.subscribe(COMMAND_TOPIC)

client.loop_start()

time.sleep(2)
 
send_msg(client, "core has started")

import threading
status_thread = threading.Thread(target=check_devices_status, daemon=True)
status_thread.start()

while True:
    time.sleep(1)