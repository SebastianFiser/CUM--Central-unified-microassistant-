---

# Test release: step-by-step guide for testers (Linux)

This package contains everything you need to run the app and backend on Linux. No additional configuration is needed – everything is ready, including `.env`.

## ZIP content
- `android_app` — Flutter app executable for Linux
- `data/`, `lib/` — support folders for Flutter
- `.env` — configuration (already filled in)
- `core.pyz` — Python core (zipapp)
- `device.pyz` — Python device simulator (zipapp)

---

## 1. Unpack the ZIP archive

Unpack the ZIP to any folder:

```sh
unzip release_v1.zip
cd release_v1
```

## 2. Run the Flutter app

Make sure you have GTK3 libraries and other dependencies installed (most distributions do).

Start the app:

```sh
./android_app
```

If it is not executable, set permissions:

```sh
chmod +x android_app
./android_app
```

## 3. Run the Python core

You need Python 3.8+ (3.10+ recommended). All dependencies are bundled inside the archive.

```sh
python3 core.pyz
```

## 4. Run the Python device simulator

```sh
python3 device.pyz --help
```

For normal run:

```sh
python3 device.pyz
```

---

## Notes
- `.env` is already prepared, you do not need to run `setup.sh`.
- If you encounter a missing library error when running the Flutter app, install e.g. `libgtk-3-0`:
	```sh
	sudo apt install libgtk-3-0
	```
- Python archives (`.pyz`) can be run on any Linux with Python 3.8+ and no extra dependencies.

---

**For testers:**
Just unpack, run, and no further configuration is needed.

---

If you have any issues, contact the developer.


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
