import time
from typing import Dict

class DeviceRecord:
    def __init__(self, device_id: str, sender_id: str, session_id: str = "", short_id: str = None):
        self.device_id = device_id
        self.sender_id = sender_id
        self.session_id = session_id
        self.status = "online"
        self.last_seen = time.time()
        self.meta = {}
        if short_id is not None:
            self.meta["short_id"] = short_id

    def to_dict(self):
        return {
            "device_id": self.device_id,
            "sender_id": self.sender_id,
            "status": self.status,
            "last_seen": self.last_seen,
            "meta": self.meta,
            "session_id": self.session_id
        }

DEVICES: Dict[str, DeviceRecord] = {}

def register_device(device_id: str, sender_id: str, session_id: str = "", meta: dict = None):

    import random, string
    def generate_short_id():
        while True:
            short_id = ''.join(random.choices(string.ascii_uppercase + string.digits, k=4))
            # Ensure uniqueness
            if all(short_id != d.meta.get("short_id") for d in DEVICES.values()):
                return short_id

    is_new_session = False

    if device_id not in DEVICES:
        short_id = generate_short_id()
        DEVICES[device_id] = DeviceRecord(device_id, sender_id, session_id, short_id=short_id)
        is_new_session = True

    device = DEVICES[device_id]
    if session_id and device.session_id != session_id:
        device.session_id = session_id
        is_new_session = True

    device.sender_id = sender_id
    device.status = "online"
    device.last_seen = time.time()
    if meta:
        device.meta.update(meta)

    return device, is_new_session

def heartbeat_device(device_id: str, session_id: str = ""):
    if device_id in DEVICES:
        device = DEVICES[device_id]
        if session_id and device.session_id and device.session_id != session_id:
            return None

        device.last_seen = time.time()
        device.status = "online"
        return device

    return None

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
    # allow lookup by short_id
    for d in DEVICES.values():
        if d.meta.get("short_id") == device_id:
            return d.to_dict()
    return None