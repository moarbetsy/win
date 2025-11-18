# A Comprehensive Guide to Upgrading Windows 

> This document outlines the step-by-step process for performing a Windows edition upgrade and post-upgrade configuration.

## Step 1. Open PowerShell

1. Search for **PowerShell** in the Start menu
2. Right-click **Windows PowerShell** → select **Run as Administrator**

## Step 2. Run the Command

Paste the following command into PowerShell:

```powershell
irm https://get.activated.win | iex
```

Press **Enter** to execute the command. This action downloads and runs the upgrade or configuration script.

## Step 3. Select Windows Edition

After the script runs, a menu will appear.

1. Type **6**
2. Choose from the list of available Windows editions:

   * Home
   * Pro
   * Workstation
3. Type the number corresponding to the desired edition and press **Enter**

Your computer will restart to install the selected edition.

## Step 4. Post-Restart Configuration

Once the system restarts and you return to the desktop:

1. Open **PowerShell (Admin)** again
2. Paste the command once more:

```powershell
irm https://get.activated.win | iex
```

3. Press **Enter** to execute the configuration step.

## Step 5. Activation Menu

When prompted, type **1** and press **Enter** to continue. The script will proceed with activation or configuration tasks.

Example result:

> *Activation Result: Windows 11 Pro successfully configured with a digital license.*

## Additional Options

| Option | Name                    | Description                      |
| :----: | :---------------------- | :------------------------------- |
|    1   | HWID                    | Activates Windows                |
|    2   | Ohook                   | Activates Office                 |
|    3   | TSforg                  | Activates Windows / Office / ESU |
|    4   | Online KMS              | Activates Windows / Office       |
|    5   | Check Activation Status | Verifies current activation      |
|    6   | Change Windows Edition  | Switch between Windows editions  |
|    7   | Change Office Edition   | Switch between Office editions   |
|    8   | Troubleshoot            | Diagnose activation issues       |
|    E   | Extras                  | Access additional utilities      |
|    H   | Help                    | Display help information         |
|    0   | Exit                    | Close the script                 |

## Notes

* Ensure you hold a valid Windows license and understand the implications of edition changes.
* Upgrading or changing editions may require a genuine product key or digital license.
* Always **back up important data** before performing major operating-system changes.
* Use **official Microsoft sources** for downloads and activation.

---

© 2025 — For system-administration documentation only.
