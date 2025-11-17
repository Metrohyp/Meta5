Good question 👍 — when you use **Option 5 → “Install MetaTrader 5 (Wine)”** in that script, it installs MT5 **inside your user’s Wine environment**, not system-wide.

Here’s exactly where everything goes and how it behaves:

---

### 📁 Installation Path

| Component                                | Location                                                                | Notes                                                                         |
| ---------------------------------------- | ----------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| **Wine prefix (Windows environment)**    | `~/.wine-mt5/`                                                          | A hidden folder in your **home directory**. This is like “C:\” for Wine apps. |
| **MetaTrader 5 program files**           | `~/.wine-mt5/drive_c/Program Files/MetaTrader 5/`                       | Contains `terminal64.exe`, `uninstall.exe`, all MT5 data and DLLs.            |
| **Installer**                            | `~/mt5setup.exe`                                                        | The downloaded installer; you can delete it after installation.               |
| **User data (profiles, accounts, etc.)** | `~/.wine-mt5/drive_c/users/$USER/Application Data/MetaQuotes/Terminal/` | Same structure as Windows `%APPDATA%`.                                        |

So nothing touches `/usr` or other system directories — it’s completely **per-user and self-contained**.

---

### 🧠 How the process works

1. **Wine prefix creation**

   ```bash
   export WINEPREFIX="$HOME/.wine-mt5"
   wineboot --init
   ```

   → creates the fake Windows C: drive under `~/.wine-mt5`.

2. **Runtime dependencies**

   ```bash
   winetricks -q corefonts vcrun2015
   ```

   → installs Visual C++ 2015 runtime and fonts that MT5 needs.

3. **Installer download**

   ```bash
   wget -O "$HOME/mt5setup.exe" "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
   ```

4. **Run inside RDP desktop**

   ```bash
   export WINEPREFIX="$HOME/.wine-mt5"
   wine "$HOME/mt5setup.exe"
   ```

   → launches the GUI wizard; choose the default path (`C:\Program Files\MetaTrader 5\`).

---

### ▶️ Launching MT5 later

From your RDP terminal:

```bash
export WINEPREFIX="$HOME/.wine-mt5"
wine "$HOME/.wine-mt5/drive_c/Program Files/MetaTrader 5/terminal64.exe"
```

Or double-click the MT5 icon if you created one on your XFCE desktop.

---

### 🧹 To remove or reset MT5

Just delete its prefix folder:

```bash
rm -rf ~/.wine-mt5
```

That wipes MT5 and all settings without affecting the rest of the system.

---

Would you like me to add an **autostart entry** so that this `terminal64.exe` runs automatically whenever you log in to your RDP desktop?
