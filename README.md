# FinVault 
> **Next-Generation Smart Loan, EMI Amortization & Repayment Ledger Vault**  
> *Engineered for private financiers, credit firms, lenders, and field collection agents. Featuring 100% on-device privacy, native cross-platform support (Android & Windows), Village Rupee Interest (Vaddi) calculation, Bank Reducing EMI, multi-language localization, and dynamic UPI QR payments.*

<p align="center">
  <a href="https://deepakgowrishankar7.github.io/FinVault/" target="_blank">
    <img src="assets/logo.png" alt="FinVault Logo" width="120" height="120" style="border-radius: 28px; box-shadow: 0 12px 32px rgba(0,113,227,0.25);" />
  </a>
</p>

<p align="center">
  <a href="https://deepakgowrishankar7.github.io/FinVault/">
    <img src="https://img.shields.io/badge/Showcase%20Page-FinVault%20v2.0-0071E3?style=for-the-badge&logo=googlechrome&logoColor=white" alt="Live Showcase Page" />
  </a>
  <a href="https://github.com/deepakgowrishankar7/FinVault/releases/download/v2.0.0/FinVault.apk">
    <img src="https://img.shields.io/badge/Android%20APK-v2.0.0%20(Fast%20Install)-34C759?style=for-the-badge&logo=android&logoColor=white" alt="Android APK" />
  </a>
  <a href="https://github.com/deepakgowrishankar7/FinVault/releases/download/v2.0.0/FinVault-Windows.zip">
    <img src="https://img.shields.io/badge/Windows%20App-Portable%20ZIP%20(.exe)-0078D7?style=for-the-badge&logo=windows&logoColor=white" alt="Windows App" />
  </a>
  <img src="https://img.shields.io/badge/Privacy-100%25%20Offline%20First-success?style=for-the-badge&logo=apple" alt="100% Offline" />
  <img src="https://img.shields.io/badge/Languages-5%20Regional-blueviolet?style=for-the-badge" alt="5 Regional Languages" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="MIT License" />
</p>

---

## 🚀 Downloads & Quick Access

* 🌐 **Official Showcase Website:**  
  👉 **[https://deepakgowrishankar7.github.io/FinVault/](https://deepakgowrishankar7.github.io/FinVault/)**  
  *Clean, professional portal featuring live feature walkthroughs, developer credentials, and 1-click downloads.*

* 📱 **Android Mobile Application (.APK):**  
  👉 **[Download FinVault.apk (~29.4 MB)](https://github.com/deepakgowrishankar7/FinVault/releases/download/v2.0.0/FinVault.apk)**  
  *Native Flutter engine delivering smooth 60–120 FPS performance, offline local storage, instant haptic keypad, and zero WebView latency.*

* 💻 **Laptop & Desktop Application (Windows .EXE):**  
  👉 **[Download FinVault-Windows.zip (~15.8 MB)](https://github.com/deepakgowrishankar7/FinVault/releases/download/v2.0.0/FinVault-Windows.zip)**  
  *Native Windows desktop build featuring a responsive, centered card interface tailored for laptop screens.*

---

## ✨ Key Highlights & Features

### 🪙 Dual Lending Interest Models
* **Village Rupee Interest (Vaddi Model / వడ్డీ విధానం):**  
  Standard rural and micro-finance calculation based on rupees per month per ₹100 principal (e.g., ₹1, ₹1.5, ₹2, ₹3 per ₹100/mo).
* **Bank Reducing Balance EMI:**  
  Standard monthly compounding EMI with transparent principal-to-interest split amortization schedules.
* **Flat Simple Interest:**  
  Fixed percentage per annum flat calculation with flexible tenure in months.

### 🌐 5 Indian Regional Languages
Fully localized with dynamic, instant language switching without restarting the app:
* **English**
* **Telugu (తెలుగు)**
* **Hindi (हिंदी)**
* **Tamil (தமிழ்)**
* **Kannada (ಕನ್ನಡ)**

### 💻 Responsive Multi-Platform Interface
* **Mobile View:** Edge-to-edge, thumb-friendly touch layout optimized for single-hand collection workflows.
* **Laptop / Desktop View:** Clean, centered card architecture (`maxWidth: 440px - 1080px`) preventing widescreen stretching and providing a focused ledger view.

### 👥 Role-Based Access Control (RBAC)
* **👑 Master Admin (Firm Owner):** Full access to total net interest profits, loan creation/editing/deletion, team management, firm code generation, and cloud sync credentials.
* **🏃 Field Collection Agent (Staff):** Purpose-built agent mode. Allows recording borrower installments and generating UPI QR codes while **confidential profit margins, loan terms, and master settings remain strictly protected**.

### ⚡ Instant Dynamic UPI QR Codes
* Generates offline byte-matrix UPI QR codes embedded with the exact payment amount and the owner's bank VPA (`upi://pay?pa=...&am=...`).
* Compatible with PhonePe, Google Pay, Paytm, BHIM, and any standard UPI application.

### 🛡️ Complete Data Portability & Backup
* **FinVault Snapshot (`.finvault`):** 1-click encrypted vault file for seamless cross-device migration.
* **Excel Spreadsheet (`.csv`):** Formatted spreadsheet with column headers and UTF-8 BOM encoding for direct opening in Microsoft Excel or Google Sheets.
* **Raw JSON Backup (`.json`):** Complete human-readable data export of all loans, payments, and settings.
* **Optional Private Cloud Sync:** Plug-and-play synchronization with your own Supabase cloud database.

---

## 👥 Role Permissions Matrix

| Feature / Screen | 👑 Master Admin (Owner) | 🏃 Field Collection Agent (Staff) |
| :--- | :---: | :---: |
| **Total Profit & Net Interest Earnings** | ✅ Full Visibility | ❌ Completely Hidden (Confidential) |
| **Disburse & Edit Loans** | ✅ Full Access | ❌ Restricted |
| **Delete Loan Records** | ✅ Full Access | ❌ Restricted (Tamper-proof) |
| **Record Installment Payments** | ✅ Allowed | ✅ Allowed (Stamped with Collector ID) |
| **Dynamic Offline UPI QR** | ✅ Configurable | ✅ Show to Borrower (Funds go to Owner) |
| **1-Click WhatsApp Receipts** | ✅ Allowed | ✅ Allowed |
| **Export Excel & Full Backups** | ✅ Full Access | ❌ Restricted |
| **Manage Staff & Passcodes** | ✅ Full Access | ❌ Restricted |

---

## 📥 Installation Guide

### For Android Phones & Tablets
1. Download `FinVault.apk` from the [Download Link](https://github.com/deepakgowrishankar7/FinVault/releases/download/v2.0.0/FinVault.apk).
2. Tap the downloaded file on your device.
3. If prompted, enable *"Install from Unknown Sources"* in browser settings.
4. Tap **Install** and launch FinVault.

### For Windows Laptop / PC
1. Download `FinVault-Windows.zip` from the [Download Link](https://github.com/deepakgowrishankar7/FinVault/releases/download/v2.0.0/FinVault-Windows.zip).
2. Right-click the `.zip` archive and select **Extract All...**.
3. Open the extracted folder and double-click **`finvault.exe`**.
4. *(Optional)* Right-click `finvault.exe` -> **Send to** -> **Desktop (create shortcut)** for 1-click access.

---

## 👨‍💻 Founder & Developer

<table border="0">
  <tr>
    <td width="150" align="center" valign="middle">
      <img src="deepak.jpg" alt="Enduri Deepak Gowri Shankar" width="130" style="border-radius: 16px; box-shadow: 0 8px 24px rgba(0,0,0,0.12);" />
    </td>
    <td valign="middle">
      <h3>Enduri Deepak Gowri Shankar</h3>
      <p><b>Computer Science Student & Software Architect</b></p>
      <p>Architect and lead developer of FinVault. Focused on building high-performance, privacy-first software solutions for private financial empowerment.</p>
      <p>
        <a href="mailto:deepakgowrishankar7@gmail.com">
          <img src="https://img.shields.io/badge/Email-deepakgowrishankar7%40gmail.com-EA4335?style=flat-square&logo=gmail&logoColor=white" alt="Email" />
        </a>
        &nbsp;
        <a href="https://www.linkedin.com/in/enduri-deepak-gowri-shankar/" target="_blank">
          <img src="https://img.shields.io/badge/LinkedIn-Deepak%20Gowri%20Shankar-0A66C2?style=flat-square&logo=linkedin&logoColor=white" alt="LinkedIn" />
        </a>
        &nbsp;
        <a href="https://github.com/deepakgowrishankar7" target="_blank">
          <img src="https://img.shields.io/badge/GitHub-deepakgowrishankar7-181717?style=flat-square&logo=github&logoColor=white" alt="GitHub" />
        </a>
      </p>
    </td>
  </tr>
</table>

---

## 📄 License

Distributed under the **MIT License**. Free for personal, commercial, and financial firm use.

---

<p align="center">
  <b>FinVault</b> — Built with privacy and precision for modern financial lending.
</p>
