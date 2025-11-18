# Windows Starter Kit (Clean)

> A streamlined, easy‑to‑scan guide for running Win11Debloat, applying system tweaks, and removing bloatware.

---

# Step 1 — Open PowerShell (Admin)

1. Open the **Start Menu**
2. Search **PowerShell**
3. Right‑click → **Run as Administrator**

---

# Step 2 — Run the Script

Copy and paste into PowerShell:

```powershell
& ([scriptblock]::Create((irm "https://debloat.raphi.re/")))
```

Then press **Enter**.

This automatically downloads & starts Win11Debloat.

---

# Step 3 — Select a Mode

When the menu appears, choose:

### **1 — Default Mode**

Most recommended tweaks + optional app removal

### **2 — Minimal Mode**

Light changes, fewer removals

### **3 — Interactive Mode**

Approve each change manually

### **4 — Revert Changes**

Undo most previously applied tweaks

Type the number and press **Enter**.

---

# Step 4 — App Removal (Optional)

If prompted, choose:

* **Remove default bloat apps**
* **Choose custom apps to remove**
* **Skip removal**

> Most removed apps can be restored via Microsoft Store.

---

# Step 5 — Privacy & Telemetry Tweaks

Win11Debloat automatically handles:

✔ Disable telemetry & diagnostic tracking
✔ Disable targeted ads & suggestions
✔ Remove Bing search results
✔ Disable Microsoft Copilot
✔ Disable Windows Recall (Win11)
✔ Disable AI features in Edge, Paint & Notepad (Win11)

---

# Additional Tweaks

Win11Debloat includes many optional improvements:

### **File Explorer**

• Show file extensions
• Show hidden files
• Hide Home/Gallery (Win11)
• Remove duplicate drive entries

### **Taskbar**

• Disable Widgets
• Change/hide Search box
• Enable "End Task" right‑click action (Win11)
• Restore last‑active‑click behavior

### **Start Menu**

• Disable Recommended section
• Disable Phone Link integration (Win11)

### **Personalization**

• Enable Dark Mode
• Disable transparency & animations
• Restore Win10 context menu (Win11)

### **System Behavior**

• Disable Fast Startup
• Disable Xbox Game Bar
• Reduce Modern Standby battery drain (Win11)

---

# Reverting Changes

You can safely undo most tweaks:

1. Re‑run the script
2. Choose **Revert Changes**
3. Reinstall apps from **Microsoft Store** if needed

---

# Automatic (No‑Menu) Mode

Run all default tweaks automatically:

```powershell
& ([scriptblock]::Create((irm "https://debloat.raphi.re/"))) -RunDefaults
```

Run defaults **without removing apps**:

```powershell
-RunDefaultsLite
```

---

# Notes

* Always create a **system restore point** first.
* Most changes are safe & reversible.
* Advanced users can automate everything with parameters.
* Ideal for clean installs, new devices, and system prep.

---
