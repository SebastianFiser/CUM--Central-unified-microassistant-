import time
from typing import Dict, Optional

class DeviceRecord:
    def __init__(self, device_id: str, sender_id: str):
        self.device_id = device_id
        self.sender_id = sender_id
        self.status = "online"
        self.last_seen = time.time()
        self.meta = {}

    def to_dict(self):
        return {
            "device_id": self.device_id,
            "sender_id": self.sender_id,
            "status": self.status,
            "last_seen": self.last_seen,
            "meta": self.meta,
        }

DEVICES: Dict[str, DeviceRecord] = {}

def register_device(device_id: str, sender_id: str, meta: dict = None):
    if device_id not in DEVICES:
        DEVICES[device_id] = DeviceRecord(device_id, sender_id)

    device = DEVICES[device_id]
    device.status = "online"
    device.last_seen = time.time()
    if meta:
        device.meta.update(meta)
    return device

def heartbeat_device(device_id: str):
    if device_id in DEVICES:
        DEVICES[device_id].last_seen = time.time()
        DEVICES[device_id].status = "online"
    return DEVICES.get(device_id)

def check_offline_devices(timeout: float = 15.0):
    now = time.time()
    offline = []
    for device_id, device in DEVICES.items():
        if device.status == "online" and (now - device.last_seen) > timeout:
            device.status = "offline"
            offline.append(device_id)
    return offline

def get_all_devices():
    return {did: d.to_dict() for did, d in DEVICES.items()}

def get_device(device_id: str):
    if device_id in DEVICES:
        return DEVICES[device_id].to_dict()
    return None