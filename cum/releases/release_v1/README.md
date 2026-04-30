# Návod na spuštění release balíčku (Linux)

Tento balíček obsahuje vše potřebné pro spuštění Flutter aplikace, Python core a device simulátor na Linuxu. Soubor `.env` je již vyplněný, není potřeba žádný další setup.

## Obsah ZIPu
- `android_app` — spustitelná Flutter aplikace pro Linux
- `data/`, `lib/` — podpůrné složky pro Flutter aplikaci
- `.env` — konfigurace (již vyplněná)
- `core.pyz` — Python core (zipapp)
- `device.pyz` — Python device simulátor (zipapp)

---

## 1. Rozbalení balíčku

Rozbalte ZIP do libovolné složky:

```sh
unzip release_v1.zip
cd release_v1
```

## 2. Spuštění Flutter aplikace

Ujistěte se, že máte nainstalované knihovny GTK3 a další závislosti (většina distribucí má vše potřebné).

Spusťte aplikaci:

```sh
./android_app
```

Pokud by nebyl spustitelný, nastavte práva:

```sh
chmod +x android_app
./android_app
```

## 3. Spuštění Python core

Potřebujete Python 3.8+ (doporučeno 3.10+). Všechny závislosti jsou zabalené v archivu.

```sh
python3 core.pyz
```

## 4. Spuštění Python device simulátoru

```sh
python3 device.pyz --help
```

Pro běžné spuštění:

```sh
python3 device.pyz
```

---

## Poznámky
- `.env` je již připravený, není potřeba spouštět `setup.sh`.
- Pokud narazíte na problém s chybějící knihovnou při spuštění Flutter aplikace, doinstalujte např. `libgtk-3-0`:
  ```sh
  sudo apt install libgtk-3-0
  ```
- Python archivy (`.pyz`) lze spouštět na libovolném Linuxu s Pythonem 3.8+ bez dalších závislostí.

---

**Pro testery:**
Stačí rozbalit, spustit, není potřeba žádná další konfigurace.

---

V případě problémů kontaktujte vývojáře.
