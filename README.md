

# CUM – Central Unified Microassistant

**CUM** is an open platform for managing, controlling, and automating devices in your home or business using AI and a central console.

DISCLAIOMER: README.MD IS a projection of FINISHED PROJECT. not according to reality 

---

## Key Features
- Centralized device control via MQTT
- Modular architecture (core, protocol, clients)
- Supports multiple devices and clients (Android, CLI, more)
- Extensible API (controller.py)
- Message validation via JSON schema
- Easy integration with AI agents

---

## Architecture

- **core/** – The system core, orchestrates communication, registry, MQTT, commands, and events
- **protocol/** – Message schema definitions (command/event), describes the communication format
- **android_app/** – Android client application

### Main API (controller.py)
All commands and messages are sent via controller.py:

```python
controller.ping_device(client, short_id)
controller.send_msg(client, short_id, text)
controller.send_brightness(client, short_id, value)
controller.send_register(client, short_id, meta={...})
controller.send_heartbeat(client, short_id)
controller.send_status_request(client, short_id)
```

---

## Getting Started

1. Start the server: `python3 cum/core/main.py` you have to have requirements.txt installed (on linux use venv)
2. Connect a device or client (best to run debug web server on localhost. bui there is a compiled project)
3. Control devices via CLI or API. Best to use in app terminal. combination of both pythno scripts and app is the best

---

## Documentation
- Detailed architecture and mini-API: `cum/documentation.md`
- High-level API and principles: `documentation.md` (root)
- Message schemas: `cum/protocol/`

---

## License
MIT
