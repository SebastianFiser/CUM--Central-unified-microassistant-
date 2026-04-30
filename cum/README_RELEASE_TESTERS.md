# CUM – Central Unified Microassistant

## Test release: step-by-step guide for testers (Linux)

This package contains everything you need to run the app and backend on Linux. No additional configuration is needed – everything is ready, including `.env`.

---

## 1. Unpack the ZIP archive

1. Download `release_v1.zip` from GitHub Releases.
2. Unpack the ZIP to any folder:
  ```sh
  unzip release_v1.zip
  cd release_v1
  ```

---

## 2. Run the Flutter app (GUI)

1. Make sure you have GTK3 libraries installed (most distributions do; if not, install with `sudo apt install libgtk-3-0`).
2. Start the app:
  ```sh
  ./android_app
  ```
  If it is not executable, set permissions:
  ```sh
  chmod +x android_app
  ./android_app
  ```

---

## 3. Run the Python backend (core)

1. You need Python 3.8+ (3.10+ recommended). No need to install any packages – everything is bundled inside.
2. Start the backend:
  ```sh
  python3 core.pyz
  ```

---

## 4. Run the simulated device

1. Again, you only need Python 3.8+.
2. For help, run:
  ```sh
  python3 device.pyz --help
  ```
3. For normal run:
  ```sh
  python3 device.pyz
  ```

---

## 5. How to check if it works

- The Flutter app should start with a graphical interface.
- The Python backend (`core.pyz`) prints logs and reacts to MQTT messages.
- The simulated device (`device.pyz`) connects to MQTT and communicates with the core.

---

## 6. Troubleshooting

- If the Flutter app reports a missing library, install it, e.g.:
  ```sh
  sudo apt install libgtk-3-0
  ```
- If Python reports a missing module, make sure you are running the `.pyz` file and have Python 3.8+.
- `.env` is already filled in, you do not need to edit anything.

---

## 7. Folder structure after unpacking

- `android_app` – Flutter app executable
- `data/`, `lib/` – support folders for Flutter
- `.env` – configuration (already filled in)
- `core.pyz` – Python backend
- `device.pyz` – Python device simulator

---

## 8. Contact

If you have any issues or feedback, contact the developer.

---

**Testing is now as simple as possible: just unpack, run, and test.**
