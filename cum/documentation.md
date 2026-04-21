# CUM (Central Unified Microassistant) – Documentation

This file describes function anbd use of API's and their mini API's

## Project structure

- **core/** – Centre of the system, orchestrates comunication, registers, MQQT, commands and happenings.
- **protocol/** – Definition of message schemes (command/event), describes form of of comunicatiion protocol between server and client.
- **android_app/** – Client app for android, witch comunicates API's,and implements client API's.

---

## core/

### Main files

- **main.py**
  - Starts cli interface for comunication.
  - uses onlnly controller.py API's.
  - main commands: `ping`, `msg`, `brightness`, `register`, `heartbeat`, `status_request`, `devices`, `log on/off`.

- **controller.py**
  - Central high level API's for all messages.
  - Builds complete MQTT messages based of schemes and sends trough publish.
  - Functions:
    - `ping_device(client, short_id)`
    - `send_msg(client, short_id, text)`
    - `send_brightness(client, short_id, value)`
    - `send_register(client, short_id, meta=None)`
    - `send_heartbeat(client, short_id)`
    - `send_status_request(client, short_id)`
  - Všechny ostatní části systému volají pouze controller.py, nikdy přímo MQTT nebo modely.

- **mqtt_client.py**
  - Contains basic MQQT utils (publish, subscribe, id generations, topic constants).
  - Doesnt contain application commands

- **models.py**
  - defines data structures and models for message building (`command_to_dict`, `event_to_dict`).

- **registry.py**
  - Evidence of devices, sessions and stzatusses.
  - Functions: `get_all_devices`, `get_device`, `register_device`, `heartbeat_device`, ...

- **router.py**
  -Routing incomming messages.

---

## protocol/

- **command.schema.json**
  - JSON Schemes for command messages (MQTT command).
  - defines required fields: `id`, `sender_id`, `type`, `action`, `payload`, ...

- **event.schema.json**
  - JSON Scheme for event messages(MQTT event).
  - Definuje defines required fields: `id`, `sender_id`, `type`, `event`, `payload`, ...
---

## android_app/

- **pubspec.yaml**
  - Flutter project config.
- MTT client implementation, wich comunicates trough protocol schemes/.
- Uses mini api on client side.

---

## Mini-API příklad (controller.py)

```python
controller.ping_device(client, "UO1T")
controller.send_msg(client, "UO1T", "Ahoj světe!")
controller.send_brightness(client, "UO1T", 42)
controller.send_register(client, "UO1T", meta={"kind": "device.py"})
controller.send_heartbeat(client, "UO1T")
controller.send_status_request(client, "UO1T")
```

---

## Zásady
- All application logic for messages are strictly only in controller.py.
- Other parts of system (CLI, GUI, events) call ONLY controller.py.
- Registers and routwr are only service layers.
