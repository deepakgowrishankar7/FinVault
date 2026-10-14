# FinVault 
> **Next-Generation Smart Loan, EMI Amortization & Repayment Ledger Vault**  
> *Engineered for micro-financiers, lenders, and lending firms. Featuring 100% on-device privacy, Apple-grade glassmorphism, multi-role team roster, offline dynamic UPI QR, and instant 1-page digital receipts.*

<p align="center">
  <img src="icon.svg" alt="FinVault Logo" width="120" height="120" style="border-radius: 28px; box-shadow: 0 10px 30px rgba(0,113,227,0.3);" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Privacy-100%25%20On--Device-success?style=for-the-badge&logo=apple" alt="100% On-Device" />
  <img src="https://img.shields.io/badge/Platform-Web%20%7C%20PWA%20%7C%20Android-0071E3?style=for-the-badge&logo=android" alt="Platforms" />
  <img src="https://img.shields.io/badge/Architecture-Vanilla%20ES6%2B-F7DF1E?style=for-the-badge&logo=javascript" alt="Vanilla JS" />
  <img src="https://img.shields.io/badge/Cloud%20Sync-Optional%20(Supabase)-3ECF8E?style=for-the-badge&logo=supabase" alt="Optional Cloud Sync" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="MIT License" />
</p>

---

## ⚡ Highlights & Key Features

* 🔒 **100% Private & Offline-First**: Zero external trackers, analytics, or ads. All borrower identities, phone numbers, and loan ledgers live **exclusively inside your device**.
* 🛡️ **Dual-Layer Anti-Deletion Storage**: Runs high-speed `localStorage` paired with an automatic background `IndexedDB` mirror (`FinVault_DB`). Automatically requests browser persistent storage lock (`navigator.storage.persist()`) to prevent OS cache eviction.
* 👥 **Multi-Role Team Management**:
  * 👑 **Master Admin (Owner)**: Unrestricted access to interest profits, total capital, team passcodes, loan editing/deletion, and cloud sync.
  * 👑 **Co-Admin (Business Partner)**: Full co-ownership management with their own secure 4-digit PIN.
  * 🏃 **Field Collection Agent (Staff)**: Dedicated collection mode. Agents can record payments and show UPI QR codes, but **all confidential net profits, loan modifications, and security controls are strictly hidden**.
* 🧾 **1-Page Print-Perfect Receipts**: Generates crisp, official digital payment vouchers with brand logo, borrower ledger summary, and signature lines — strictly formatted to a single page on paper or PDF.
* 📷 **Zero-Network Dynamic UPI QR Code**: Instantly generates an offline byte-matrix UPI QR code configured with the borrower's exact installment amount and the owner's bank VPA (`upi://pay?pa=...&am=...`).
* 💬 **1-Tap WhatsApp Alerts**: Formatted payment reminders and balance receipts sent directly to borrowers via WhatsApp with one tap.
* 📱 **PWA & Native Android Ready**: Runs full-screen with offline caching on iPhone, Android, iPad, and desktop browsers, with native Capacitor Android bindings included.

---

## 👥 Role Permissions Matrix

FinVault features an **Apple-style Glassmorphic Passcode Lock & Role Selector**:

| Feature / Screen | 👑 Master Admin (Owner) | 👑 Co-Admin (Business Partner) | 🏃 Field Collection Agent (Staff) |
| :--- | :---: | :---: | :---: |
| **Total Profit & Net Interest Earnings** | ✅ Full Access | ✅ Full Access | ❌ Completely Hidden (Confidential) |
| **Create & Edit Loans** | ✅ Full Access | ✅ Full Access | ❌ Restricted |
| **Delete Loans** | ✅ Full Access | ✅ Full Access | ❌ Restricted (Tamper-proof) |
| **Record Installment Payments** | ✅ Full Access | ✅ Full Access | ✅ Allowed (Stamped with Agent's Name) |
| **Dynamic Offline UPI QR Code** | ✅ Configurable | ✅ Configurable | ✅ Show to Borrower (Money goes to Owner) |
| **Print / WhatsApp Receipts** | ✅ Allowed | ✅ Allowed | ✅ Allowed (Shows *"Collected By: [Name]"*) |
| **Add / Deactivate Team Members** | ✅ Full Access | ✅ Full Access | ❌ Restricted |
| **Passcode & Cloud Sync Settings** | ✅ Full Access | ✅ Full Access | ❌ Restricted |

---

## 🛡️ Anti-Deletion & Data Portability

1. **Dual Storage Engines**: High-speed `localStorage` synchronized with a background `IndexedDB` mirror. If browser data is ever cleared, FinVault automatically restores your books upon launch.
2. **1-Click Portable Vault (`.dgsvault`)**: Export an encrypted, portable snapshot of all active loans, repayment ledgers, and team security keys.
3. **Cross-Device Vault Migration**: Transfer your `.dgsvault` between phones, tablets, and laptops via WhatsApp, USB, or Google Drive, and restore in 1 click on the Setup Wizard or Lock Screen.
4. **Excel / CSV Export**: Generate raw `.csv` spreadsheets for accounting software or tax audits.

---

## ☁️ Optional Private Cloud Sync (Supabase)

For financiers who want automated multi-device cloud synchronization while keeping 100% ownership of their database:

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
4. Enter your Supabase Project URL and Public Anon Key, then tap **"Save Cloud Sync Credentials"**.
5. Tap **"☁️ Sync Now"** anytime to push or pull changes across all your authorized devices.

---

## 🚀 How to Run & Deploy (100% Free)

### Option 1: Free GitHub Pages Web App (Install on Android & iOS)
1. Fork or push this repository to GitHub.
2. Go to **Settings > Pages** in your GitHub repository.
3. Under **Branch**, select `main` and root `/` (or `/www`), then click **Save**.
4. You will receive a live URL: `https://<username>.github.io/FinVault/`
5. Open this link on your phone in Chrome or Safari and tap **"Install App"** / **"Add to Home Screen"**. FinVault will install as an offline mobile app!

### Option 2: Run Locally on Laptop / PC
Simply double-click [`index.html`](index.html) in your browser, or run:
```powershell
# Using Node / NPX
npx serve www
```

### Option 3: Native Android APK Build (Capacitor)
```powershell
# 1. Build the distribution bundle
node build.js

# 2. Sync web assets with native Android project
npx cap sync android

# 3. Open in Android Studio to build APK
npx cap open android
```
*(In Android Studio: Click **Build > Build Bundle(s) / APK(s) > Build APK(s)** to generate your release `.apk` file).*

---

## 🛠️ Tech Stack & Philosophy

* **Pure Vanilla ES6+**: Zero dependency bloat, zero runtime framework overhead. Fast 60 FPS performance on all devices.
* **Modern CSS3 Glassmorphism**: Tailored Apple dark-mode aesthetics, responsive flexbox/grid layout, and zero scrollbar clutter.
* **Service Worker Cache API**: Instant offline loading and PWA compliance.
* **Canvas Byte-Matrix**: Embedded mathematical UPI QR generation without third-party network APIs.

---

## 📄 License

Distributed under the **MIT License**. Free for personal, commercial, and firm use.

---

<p align="center">
  <b>FinVault</b> — Built with privacy and precision for modern financial lending.
</p>
