# FinVault 
> **Next-Generation Smart Loan, EMI Amortization & Repayment Ledger Vault**  
> *Engineered for micro-financiers, lenders, and lending firms. Featuring 100% on-device privacy, Apple-grade glassmorphism, multi-role team roster, offline dynamic UPI QR, and instant 1-page digital receipts.*

<p align="center">
  <a href="https://deepakgowrishankar7.github.io/FinVault/" target="_blank">
    <img src="icon.svg" alt="FinVault Logo" width="128" height="128" style="border-radius: 28px; box-shadow: 0 12px 32px rgba(0,113,227,0.25);" />
  </a>
</p>

<p align="center">
  <a href="https://deepakgowrishankar7.github.io/FinVault/">
    <img src="https://img.shields.io/badge/Live%20Web%20App-FinVault-0071E3?style=for-the-badge&logo=googlechrome&logoColor=white" alt="Live Web App" />
  </a>
  <a href="https://github.com/deepakgowrishankar7/FinVault/releases">
    <img src="https://img.shields.io/badge/Android%20APK-Flutter%2060--120%20FPS-34C759?style=for-the-badge&logo=android&logoColor=white" alt="Flutter Native APK" />
  </a>
  <img src="https://img.shields.io/badge/Privacy-100%25%20On--Device-success?style=for-the-badge&logo=apple" alt="100% On-Device" />
  <img src="https://img.shields.io/badge/Cloud%20Sync-Supabase%20Ready-3ECF8E?style=for-the-badge&logo=supabase" alt="Cloud Sync" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="MIT License" />
</p>

---

## 🌐 Live Web Application & Mobile Access

* 🌍 **Live Production Web App:**  
  👉 **[https://deepakgowrishankar7.github.io/FinVault/](https://deepakgowrishankar7.github.io/FinVault/)**  
  *Open in any desktop browser (Chrome, Safari, Edge, Firefox) or mobile browser. Tap **"Install App"** / **"Add to Home Screen"** to run full-screen as an offline PWA!*

* 📱 **Native Flutter Android App (.APK):**  
  👉 **[Download Latest FinVault APK (GitHub Releases)](https://github.com/deepakgowrishankar7/FinVault/releases)**  
  *Engineered with native Flutter for buttery-smooth 60–120 FPS performance, offline local storage, instant haptic keypad, and zero WebView latency.*

---

## ⚡ Highlights & Key Features

* 🚀 **True 60–120 FPS Performance**: Powered by a Flutter native mobile client alongside a lightweight, responsive vanilla Web PWA.
* 🔒 **100% Private & Offline-First**: Zero third-party trackers, analytics, or ads. All borrower identities, phone numbers, and loan ledgers live **exclusively inside your device**.
* 🛡️ **Dual-Layer Anti-Deletion Storage**: Runs high-speed local persistence synchronized with a background database mirror. Automatically prevents OS cache eviction.
* 👥 **Multi-Role Team Management**:
  * 👑 **Master Admin (Owner)**: Complete oversight of net interest profits, total capital disbursed, team passcodes, loan editing/deletion, and cloud sync credentials.
  * 🏃 **Field Collection Agent (Staff)**: Dedicated agent mode. Agents can record payments and show UPI QR codes, but **all confidential net profits, loan modifications, and security controls are strictly hidden**.
* 🧾 **1-Page Print-Perfect Receipts**: Generates crisp, official digital payment vouchers with brand logo, borrower ledger summary, and signature lines — strictly formatted to a single page on paper or PDF.
* 📷 **Zero-Network Dynamic UPI QR Code**: Instantly generates an offline byte-matrix UPI QR code configured with the borrower's exact installment amount and the owner's bank VPA (`upi://pay?pa=...&am=...`).
* 💬 **1-Tap WhatsApp Alerts**: Formatted payment reminders and balance receipts sent directly to borrowers via WhatsApp with one tap.

---

## 👥 Role Permissions Matrix

FinVault features an **Apple-style Glassmorphic Passcode Lock & Role Selector**:

| Feature / Screen | 👑 Master Admin (Owner) | 🏃 Field Collection Agent (Staff) |
| :--- | :---: | :---: |
| **Total Profit & Net Interest Earnings** | ✅ Full Access | ❌ Completely Hidden (Confidential) |
| **Create & Edit Loans** | ✅ Full Access | ❌ Restricted |
| **Delete Loans** | ✅ Full Access | ❌ Restricted (Tamper-proof) |
| **Record Installment Payments** | ✅ Full Access | ✅ Allowed (Stamped with Agent's Name) |
| **Dynamic Offline UPI QR Code** | ✅ Configurable | ✅ Show to Borrower (Funds sent to Owner VPA) |
| **Print / WhatsApp Receipts** | ✅ Allowed | ✅ Allowed (Shows *"Collected By: [Name]"*) |
| **Add / Deactivate Team Members** | ✅ Full Access | ❌ Restricted |
| **Passcode & Cloud Sync Settings** | ✅ Full Access | ❌ Restricted |

---

## ☁️ Optional Private Cloud Sync (Supabase)

For financiers who want automated multi-device cloud synchronization across Web and Android while keeping 100% ownership of their database:

1. Create a free project at [supabase.com](https://supabase.com).
2. Run this SQL query in your Supabase SQL Editor:
```sql
create table if not exists loans (
  id text primary key,
  borrower text,
  phone text,
  principal numeric,
  interest numeric,
  tenure numeric,
  model text,
  startDate text,
  created bigint,
  notes text,
  payments jsonb default '[]'::jsonb
);
alter table loans enable row level security;
create policy "Allow all operations with anon key" on loans for all using (true) with check (true);
```
3. Open **FinVault -> Settings -> Private Cloud Sync**.
4. Enter your Supabase Project URL and Public Anon Key, then tap **"Save & Connect"**.
5. Tap **"☁️ Sync Now"** anytime to push or pull changes across all your authorized devices.

---

## 🏗️ Architecture & Development

### 1. Web Application & PWA
- **Location:** Root directory (`index.html`, `styles.css`, `app.js`)
- **Hosting:** [GitHub Pages](https://deepakgowrishankar7.github.io/FinVault/)
- **Build Command:**
```powershell
node build.js
```

### 2. Native Flutter Android Application
- **Location:** `mobile/` directory
- **Compilation:** Automated via GitHub Actions CI (`.github/workflows/build-apk.yml`) on every push to `main`.
- **Local Build:**
```powershell
cd mobile
flutter pub get
flutter build apk --release
```

---

## 📄 License

Distributed under the **MIT License**. Free for personal, commercial, and firm use.

---

<p align="center">
  <b>FinVault</b> — Built with privacy and precision for modern financial lending.
</p>
