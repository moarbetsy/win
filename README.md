### **A Comprehensive Guide to Upgrading Windows 11 Home to Pro**

Upgrading from Windows 11 Home to Pro unlocks powerful features designed for professionals and advanced users, including BitLocker encryption, Remote Desktop, and advanced networking tools. This guide provides step-by-step instructions for a secure and legitimate upgrade.

---

### **1. In-Place Upgrade Using a Windows 11 ISO File**

This method is useful if you need to repair your current Windows installation while also upgrading to Pro. It essentially reinstalls Windows over itself, keeping your files and apps intact.

**1.1: Download the Official Windows 11 ISO**
*   Go to the official [Microsoft Software Download page for Windows 11](https://www.microsoft.com/software-download/windows11).
*   Scroll to the **"Download Windows 11 Disk Image (ISO)"** section.
*   Select **"Windows 11 (multi-edition ISO)"** from the dropdown menu and click **Download**.
*   Choose your product language, click **Confirm**, and then click the **"64-bit Download"** button to save the file.

**1.2: Mount the ISO File**
*   Once the download is finished, find the ISO file in your Downloads folder.
*   Right-click the ISO file and select **Mount**. This will create a virtual drive in This PC, allowing you to access its contents.

**1.3: Run the Windows 11 Setup**
*   Open the newly mounted virtual drive and double-click the **setup.exe** file.
*   Click **Yes** if a User Account Control prompt appears.
*   Follow the on-screen instructions, accepting the license terms.
*   On the **"Ready to install"** screen, ensure that **"Keep personal files and apps"** is selected. This is crucial to avoid losing your data.
*   Click **Install** to begin. Your computer will restart several times during this process.

**1.4: Activate Windows 11 Pro**
*   After the in-place upgrade is complete, your system will be running Windows 11 Pro but will not be activated yet.
*   To activate it, follow the steps in **Method 2** above by going to **Settings > System > Activation** and entering your valid Windows 11 Pro product key.

---

### **2. Activate Windows 11 Pro Using Microsoft Activation Scripts**

After the in-place upgrade is complete, your system will be running an inactivated version of Windows 11 Pro. The following steps detail how to use the massgravel script for activation.

**2.1: Open PowerShell as Administrator:**
*   Click the **Start** button, type "PowerShell".
*   Right-click on **Windows PowerShell** in the search results and select **"Run as administrator"**.
*   Click **Yes** on the User Account Control prompt.

**2.2: Run the Activation Script:**
*   In the blue PowerShell window, copy and paste the following command, then press **Enter**:
        ```powershell
        irm https://massgrave.dev/get | iex
        ```
*   This command downloads and executes the activation script.

**2.3: Follow the On-Screen Menu:**
*   An activation menu will appear in the PowerShell window with several options.
*   For a permanent activation of Windows, select the **HWID (Hardware ID)** activation option. Type the corresponding number for this option and press **Enter**.
*   The script will run and confirm once the activation is successful.

**2.4: Verify Activation:**
*   Once the script finishes, you can check your activation status.
*   Go to **Settings > System > Activation**.
*   It should now show that Windows 11 Pro is active.
