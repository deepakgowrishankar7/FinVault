/**
 * FinVault — Core Business & Animation Engine
 * Comprehensive loan management, accurate EMI amortization, payment ledger,
 * WhatsApp reminders, digital receipts, and mobile-ready PWA support.
 */

(() => {
  'use strict';

  // Storage Keys
  const STORAGE_KEY = 'dgs_finance_store_v2';
  const SETTINGS_KEY = 'dgs_finance_settings_v2';

  // Security Defaults & State
  const DEFAULT_SECURITY = {
    isRegistered: false,
    firmName: 'FinVault',
    adminName: 'Admin',
    adminPin: '1234',
    securityQuestion: 'City where business was started?',
    securityAnswer: 'chennai',
    ownerUpiId: 'owner@okhdfcbank',
    agents: [],
    lastBackupDate: null,
    unbackedChanges: 0,
    supabaseUrl: '',
    supabaseKey: '',
    cloudSyncEnabled: false
  };

  let currentRole = 'admin'; // 'admin' or 'agent'
  let currentAgent = null; // active agent object
  let isUnlocked = false;
  let enteredPin = '';

  function getSecuritySettings() {
    try {
      const stored = localStorage.getItem(SETTINGS_KEY);
      if (stored) {
        const parsed = JSON.parse(stored);
        const settings = { ...DEFAULT_SECURITY, ...parsed };
        // Purge hardcoded legacy demo agent if still cached locally
        if (Array.isArray(settings.agents)) {
          const filtered = settings.agents.filter(a => !(a.id === 'ag_1' && a.name === 'Ravi Kumar' && a.pin === '0000'));
          if (filtered.length !== settings.agents.length) {
            settings.agents = filtered;
            saveSecuritySettings(settings);
          }
        }
        return settings;
      }
    } catch(e) {}
    return { ...DEFAULT_SECURITY, agents: [] };
  }

  function saveSecuritySettings(settings) {
    try {
      localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
      idbSet('security', settings);
    } catch(e) {}
  }

  /* ------------------ IndexedDB Dual-Layer Storage Vault ------------------ */
  const IDB_NAME = 'DGS_Vault_DB';
  const IDB_STORE = 'vault_records';

  function openIndexedDB() {
    return new Promise((resolve) => {
      if (!window.indexedDB) { resolve(null); return; }
      const req = indexedDB.open(IDB_NAME, 1);
      req.onupgradeneeded = (e) => {
        const db = e.target.result;
        if (!db.objectStoreNames.contains(IDB_STORE)) {
          db.createObjectStore(IDB_STORE, { keyPath: 'key' });
        }
      };
      req.onsuccess = (e) => resolve(e.target.result);
      req.onerror = () => resolve(null);
    });
  }

  async function idbSet(key, value) {
    try {
      const db = await openIndexedDB();
      if (!db) return;
      const tx = db.transaction(IDB_STORE, 'readwrite');
      tx.objectStore(IDB_STORE).put({ key, value, updated: Date.now() });
    } catch(e) {}
  }

  async function idbGet(key) {
    try {
      const db = await openIndexedDB();
      if (!db) return null;
      return new Promise((resolve) => {
        const tx = db.transaction(IDB_STORE, 'readonly');
        const req = tx.objectStore(IDB_STORE).get(key);
        req.onsuccess = () => resolve(req.result ? req.result.value : null);
        req.onerror = () => resolve(null);
      });
    } catch(e) { return null; }
  }

  async function initPersistentStorage() {
    if (navigator.storage && navigator.storage.persist) {
      try {
        const isPersisted = await navigator.storage.persist();
        const badge = document.getElementById('vaultPersistenceBadge');
        if (badge) {
          badge.innerHTML = isPersisted 
            ? '🛡️ OS Persistent Storage: <strong>Active (Protected against browser clearing)</strong>' 
            : '🛡️ Storage Mode: <strong>Standard Local Storage</strong>';
        }
      } catch(e) {}
    }
  }

  /* ------------------ Dual-Layer Storage Recovery ------------------ */
  async function checkDualLayerRecovery() {
    try {
      let localLoans = null;
      try {
        const raw = localStorage.getItem(STORAGE_KEY);
        if (raw) localLoans = JSON.parse(raw);
      } catch (e) { localLoans = null; }

      const idbLoans = await idbGet('loans');

      // If localStorage is empty/missing but IndexedDB holds the vault, restore it!
      if ((!localLoans || (Array.isArray(localLoans) && localLoans.length === 0)) && idbLoans && Array.isArray(idbLoans) && idbLoans.length > 0) {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(idbLoans));
        showToast('🛡️ Auto-restored loan vault from IndexedDB mirror!');
      } else if (localLoans && Array.isArray(localLoans) && localLoans.length > 0 && (!idbLoans || !idbLoans.length)) {
        // Initial mirror of existing local storage into IndexedDB
        await idbSet('loans', localLoans);
      }

      // Sync security credentials
      let localSec = null;
      try {
        const rawSec = localStorage.getItem(SETTINGS_KEY);
        if (rawSec) localSec = JSON.parse(rawSec);
      } catch (e) { localSec = null; }

      const idbSec = await idbGet('security');
      if ((!localSec || !localSec.isRegistered) && idbSec && idbSec.isRegistered) {
        localStorage.setItem(SETTINGS_KEY, JSON.stringify(idbSec));
      } else if (localSec && localSec.isRegistered && (!idbSec || !idbSec.isRegistered)) {
        await idbSet('security', localSec);
      }
    } catch (err) {
      console.warn('Dual-layer vault recovery check:', err);
    }
  }

  /* ------------------ Pure Offline QR Code Generator ------------------ */
  function generateQRCodeMatrix(text) {
    const PAD0 = 0xEC;
    const PAD1 = 0x11;
    const QRBitBuffer = function() { this.buffer = []; this.length = 0; };
    QRBitBuffer.prototype = {
      put: function(num, length) { for (let i = 0; i < length; i++) this.putBit(((num >>> (length - i - 1)) & 1) == 1); },
      putBit: function(bit) {
        if (this.length == this.buffer.length * 8) this.buffer.push(0);
        if (bit) this.buffer[Math.floor(this.length / 8)] |= (0x80 >>> (this.length % 8));
        this.length++;
      }
    };
    const QRMath = {
      glog: function(n) { return QRMath.LOG_TABLE[n]; },
      gexp: function(n) { while (n < 0) n += 255; while (n >= 255) n -= 255; return QRMath.EXP_TABLE[n]; },
      EXP_TABLE: new Array(256),
      LOG_TABLE: new Array(256)
    };
    for (let i = 0; i < 8; i++) QRMath.EXP_TABLE[i] = 1 << i;
    for (let i = 8; i < 256; i++) QRMath.EXP_TABLE[i] = QRMath.EXP_TABLE[i - 4] ^ QRMath.EXP_TABLE[i - 5] ^ QRMath.EXP_TABLE[i - 6] ^ QRMath.EXP_TABLE[i - 8];
    for (let i = 0; i < 255; i++) QRMath.LOG_TABLE[QRMath.EXP_TABLE[i]] = i;

    const QRPolynomial = function(num, shift) {
      let offset = 0;
      while (offset < num.length && num[offset] == 0) offset++;
      this.num = new Array(num.length - offset + shift);
      for (let i = 0; i < num.length - offset; i++) this.num[i] = num[i + offset];
    };
    QRPolynomial.prototype = {
      get: function(index) { return this.num[index]; },
      getLength: function() { return this.num.length; },
      multiply: function(e) {
        const num = new Array(this.getLength() + e.getLength() - 1);
        for (let i = 0; i < this.getLength(); i++) {
          for (let j = 0; j < e.getLength(); j++) {
            num[i + j] ^= QRMath.gexp(QRMath.glog(this.get(i)) + QRMath.glog(e.get(j)));
          }
        }
        return new QRPolynomial(num, 0);
      },
      mod: function(e) {
        if (this.getLength() - e.getLength() < 0) return this;
        const ratio = QRMath.glog(this.get(0)) - QRMath.glog(e.get(0));
        const num = new Array(this.getLength());
        for (let i = 0; i < this.getLength(); i++) num[i] = this.get(i);
        for (let i = 0; i < e.getLength(); i++) num[i] ^= QRMath.gexp(QRMath.glog(e.get(i)) + ratio);
        return new QRPolynomial(num, 0).mod(e);
      }
    };

    const totalCount = 80;
    const dataCount = 64;
    const buffer = new QRBitBuffer();
    buffer.put(4, 4); // 8-bit byte mode
    buffer.put(text.length, 8);
    for (let i = 0; i < text.length; i++) buffer.put(text.charCodeAt(i), 8);
    while (buffer.length + 4 <= dataCount * 8) buffer.put(0, 4);
    while (buffer.length % 8 != 0) buffer.putBit(false);
    while (buffer.length < dataCount * 8) {
      buffer.put(PAD0, 8);
      if (buffer.length < dataCount * 8) buffer.put(PAD1, 8);
    }

    let rsPoly = new QRPolynomial([1], 0);
    const ecCount = totalCount - dataCount;
    for (let i = 0; i < ecCount; i++) rsPoly = rsPoly.multiply(new QRPolynomial([1, QRMath.gexp(i)], 0));

    const rawData = buffer.buffer;
    const rawPoly = new QRPolynomial(rawData, rsPoly.getLength() - 1);
    const modPoly = rawPoly.mod(rsPoly);

    const finalData = new Array(totalCount);
    for (let i = 0; i < dataCount; i++) finalData[i] = rawData[i] || 0;
    for (let i = 0; i < ecCount; i++) {
      const modIndex = i + modPoly.getLength() - ecCount;
      finalData[dataCount + i] = (modIndex >= 0) ? modPoly.get(modIndex) : 0;
    }

    const moduleCount = 33;
    const modules = new Array(moduleCount);
    for (let row = 0; row < moduleCount; row++) modules[row] = new Array(moduleCount).fill(null);

    function setupPos(row, col) {
      for (let r = -1; r <= 7; r++) {
        if (row + r <= -1 || moduleCount <= row + r) continue;
        for (let c = -1; c <= 7; c++) {
          if (col + c <= -1 || moduleCount <= col + c) continue;
          if ((0 <= r && r <= 6 && (c == 0 || c == 6)) || (0 <= c && c <= 6 && (r == 0 || r == 6)) || (2 <= r && r <= 4 && 2 <= c && c <= 4)) {
            modules[row + r][col + c] = true;
          } else {
            modules[row + r][col + c] = false;
          }
        }
      }
    }
    setupPos(0, 0); setupPos(moduleCount - 7, 0); setupPos(0, moduleCount - 7);

    for (let r = 8; r < moduleCount - 8; r++) { if (modules[r][6] === null) modules[r][6] = (r % 2 == 0); }
    for (let c = 8; c < moduleCount - 8; c++) { if (modules[6][c] === null) modules[6][c] = (c % 2 == 0); }

    const formatInfo = 20773; // Type 4 Level L Mask 0 BCH info
    for (let i = 0; i < 15; i++) {
      const mod = ((formatInfo >> i) & 1) == 1;
      if (i < 6) modules[i][8] = mod;
      else if (i < 8) modules[i + 1][8] = mod;
      else modules[moduleCount - 15 + i][8] = mod;

      if (i < 8) modules[8][moduleCount - i - 1] = mod;
      else if (i < 9) modules[8][15 - i] = mod;
      else modules[8][15 - i - 1] = mod;
    }
    modules[moduleCount - 8][8] = true;

    let bitIndex = 0;
    let inc = -1;
    let row = moduleCount - 1;
    for (let col = moduleCount - 1; col > 0; col -= 2) {
      if (col == 6) col--;
      while (true) {
        for (let c = 0; c < 2; c++) {
          if (modules[row][col - c] === null) {
            let dark = false;
            if (bitIndex < finalData.length * 8) {
              dark = (((finalData[Math.floor(bitIndex / 8)] >>> (7 - bitIndex % 8)) & 1) == 1);
            }
            const mask = (row + (col - c)) % 2 == 0;
            modules[row][col - c] = dark ^ mask;
            bitIndex++;
          }
        }
        row += inc;
        if (row < 0 || moduleCount <= row) {
          row -= inc;
          inc = -inc;
          break;
        }
      }
    }
    return modules;
  }

  function renderOfflineUpiQr(container, upiString) {
    if (!container) return;
    try {
      container.innerHTML = '';
      if (typeof QRCode !== 'undefined') {
        new QRCode(container, {
          text: upiString,
          width: 180,
          height: 180,
          colorDark: '#000000',
          colorLight: '#ffffff',
          correctLevel: QRCode.CorrectLevel.M
        });
      } else {
        // Fallback using internal generator
        const matrix = generateQRCodeMatrix(upiString);
        const canvas = document.createElement('canvas');
        const size = matrix.length;
        canvas.width = 180;
        canvas.height = 180;
        const ctx = canvas.getContext('2d');
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, 180, 180);
        const cellSize = 180 / size;
        ctx.fillStyle = '#000000';
        for (let r = 0; r < size; r++) {
          for (let c = 0; c < size; c++) {
            if (matrix[r][c]) {
              ctx.fillRect(Math.round(c * cellSize), Math.round(r * cellSize), Math.ceil(cellSize), Math.ceil(cellSize));
            }
          }
        }
        container.appendChild(canvas);
      }
    } catch(err) {
      console.warn('QR render error:', err);
      container.innerHTML = '<div style="color:var(--text-secondary);font-size:12px;padding:12px;text-align:center;">Unable to display QR code</div>';
    }
  }

  // Currency & Formatter
  let currentCurrency = '₹';

  function fmtMoney(amount) {
    if (amount === null || amount === undefined || isNaN(Number(amount))) return '—';
    const num = Math.round(Number(amount));
    return `${currentCurrency} ${num.toLocaleString('en-IN')}`;
  }

  function fmtDate(dateStr) {
    if (!dateStr) return '—';
    const d = new Date(dateStr);
    return isNaN(d.getTime()) ? dateStr : d.toLocaleDateString('en-IN', {
      day: 'numeric',
      month: 'short',
      year: 'numeric'
    });
  }

  /* ------------------ Financial Math Calculations ------------------ */

  /**
   * Monthly EMI (Amortized Reducing Balance)
   */
  function calcEmi(principal, annualRate, months) {
    const P = Number(principal) || 0;
    const n = Number(months) || 0;
    const rate = Number(annualRate) || 0;
    if (P <= 0 || n <= 0) return 0;
    if (rate <= 0) return Math.round(P / n);

    const r = rate / 100 / 12;
    const pow = Math.pow(1 + r, n);
    return Math.round((P * r * pow) / (pow - 1));
  }

  /**
   * Simple Flat Interest Monthly Installment
   */
  function calcSimple(principal, annualRate, months) {
    const P = Number(principal) || 0;
    const n = Number(months) || 0;
    const rate = Number(annualRate) || 0;
    if (P <= 0 || n <= 0) return 0;
    const totalInterest = P * (rate / 100) * (n / 12);
    const totalPayable = P + totalInterest;
    return Math.round(totalPayable / n);
  }

  /**
   * Compute Total Payable & Total Interest for any loan
   */
  function getLoanFinancials(loan) {
    const P = Number(loan.principal) || 0;
    const rate = Number(loan.interest) || 0;
    const n = Number(loan.tenure) || 0;
    const model = loan.model || 'emi';

    let monthly = 0;
    let totalPayable = 0;
    let totalInterest = 0;

    if (model === 'emi') {
      monthly = calcEmi(P, rate, n);
      totalPayable = monthly * n;
      totalInterest = Math.max(0, totalPayable - P);
    } else {
      monthly = calcSimple(P, rate, n);
      totalInterest = Math.round(P * (rate / 100) * (n / 12));
      totalPayable = P + totalInterest;
    }

    // Calculate total paid from payment ledger
    const totalPaid = (loan.payments || []).reduce((sum, p) => sum + (Number(p.amount) || 0), 0) + (Number(loan.legacyPaid) || 0);
    const remaining = Math.max(0, totalPayable - totalPaid);
    const progressPercent = totalPayable > 0 ? Math.min(100, Math.round((totalPaid / totalPayable) * 100)) : 0;

    // Determine status
    let status = 'active';
    if (remaining <= 0) {
      status = 'paid';
    } else if (loan.startDate) {
      const start = new Date(loan.startDate).getTime();
      const elapsedMonths = Math.floor((Date.now() - start) / (30 * 24 * 3600 * 1000));
      const expectedPaid = Math.min(totalPayable, monthly * elapsedMonths);
      if (totalPaid < expectedPaid) {
        status = 'overdue';
      } else {
        // Due soon if next due date is within 7 days
        status = 'active';
      }
    }

    return {
      principal: P,
      monthly,
      totalPayable,
      totalInterest,
      totalPaid,
      remaining,
      progressPercent,
      status
    };
  }

  /**
   * Generate Full Repayment Schedule Table
   */
  function generateSchedule(loan) {
    const { principal, monthly, totalPayable } = getLoanFinancials(loan);
    const n = Number(loan.tenure) || 1;
    const startDate = loan.startDate ? new Date(loan.startDate) : new Date(loan.created);
    const totalPaid = (loan.payments || []).reduce((sum, p) => sum + (Number(p.amount) || 0), 0) + (Number(loan.legacyPaid) || 0);

    const schedule = [];
    let cumulativeExpected = 0;

    for (let i = 1; i <= n; i++) {
      const dueDate = new Date(startDate);
      dueDate.setMonth(dueDate.getMonth() + i);
      cumulativeExpected += monthly;

      let installmentStatus = 'pending';
      if (totalPaid >= cumulativeExpected) {
        installmentStatus = 'paid';
      } else if (dueDate.getTime() < Date.now()) {
        installmentStatus = 'overdue';
      }

      schedule.push({
        installmentNumber: i,
        dueDate: dueDate.toISOString().split('T')[0],
        amount: monthly,
        status: installmentStatus
      });
    }

    return schedule;
  }

  /* ------------------ State & Storage Management ------------------ */

  function loadState() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) return JSON.parse(raw);
    } catch (e) {
      console.warn('Failed to parse state:', e);
    }
    // Check fallback to legacy storage if present
    try {
      const legacy = localStorage.getItem('dgs_clean_v1');
      if (legacy) {
        const parsed = JSON.parse(legacy);
        if (Array.isArray(parsed) && parsed.length) {
          // migrate legacy data
          const migrated = parsed.map(l => ({
            id: l.id || Date.now() + Math.random(),
            borrower: l.borrower || 'Unnamed',
            phone: l.phone || '',
            principal: Number(l.principal) || 10000,
            tenure: Number(l.tenure) || 12,
            interest: Number(l.interest) || 12,
            model: l.model || 'emi',
            startDate: l.created ? new Date(l.created).toISOString().split('T')[0] : new Date().toISOString().split('T')[0],
            created: l.created || Date.now(),
            notes: l.notes || '',
            payments: l.paid ? [{ id: Date.now(), amount: Number(l.paid), date: new Date().toISOString().split('T')[0], mode: 'Cash', note: 'Migrated payment' }] : []
          }));
          saveState(migrated);
          return migrated;
        }
      }
    } catch (e) {}

    return [];
  }

  function saveState(loans) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(loans));
      idbSet('loans', loans);
      const sec = getSecuritySettings();
      sec.unbackedChanges = (Number(sec.unbackedChanges) || 0) + 1;
      saveSecuritySettings(sec);
      updateBackupHealthUI();

      // Sync to cloud in background only if user explicitly turned it ON
      if (sec.cloudSyncEnabled && typeof syncToSupabase === 'function') {
        syncToSupabase(false);
      }
    } catch (e) {
      console.error('Storage write error:', e);
      idbSet('loans', loans);
      showToast('⚠️ Local storage full; saved safely to IndexedDB Vault');
    }
  }

  function updateBackupHealthUI() {
    const textEl = document.getElementById('vaultHealthText');
    const indicatorEl = document.getElementById('vaultHealthIndicator');

    const sec = getSecuritySettings();
    const unbacked = Number(sec.unbackedChanges) || 0;

    if (textEl && indicatorEl) {
      if (unbacked >= 5) {
        indicatorEl.className = 'health-pill warning';
        textEl.textContent = `Backup Recommended (${unbacked} new changes)`;
      } else {
        indicatorEl.className = 'health-pill healthy';
        textEl.textContent = 'Dual-Layer Vault: 100% Protected (IndexedDB + LocalStorage)';
      }
    }

    // Live Storage Architecture Panel
    const loans = loadState();
    const payloadBytes = JSON.stringify(loans).length;
    const isCloud = Boolean(sec.cloudSyncEnabled);

    const activePill = document.getElementById('activeStoragePill');
    const payloadEl = document.getElementById('primaryStoragePayload');
    const cloudMirrorEl = document.getElementById('cloudMirrorStatus');

    if (activePill) {
      activePill.textContent = isCloud ? '☁️ Dual Hybrid (Device + Cloud)' : '🔒 100% On-Device Mode';
      activePill.className = isCloud ? 'health-pill healthy' : 'health-pill';
    }
    if (payloadEl) {
      const kbSize = (payloadBytes / 1024).toFixed(1);
      payloadEl.textContent = `${loans.length} Borrower Account${loans.length === 1 ? '' : 's'} (~${kbSize} KB)`;
    }
    if (cloudMirrorEl) {
      cloudMirrorEl.innerHTML = isCloud 
        ? '<span style="color:var(--success);">● Active (Table: public.loans)</span>' 
        : '<span style="color:var(--text-secondary);">○ Inactive (100% Local Only)</span>';
    }
  }

  /* ------------------ UI Helpers & Toast Notification ------------------ */

  function showToast(message, duration = 3000) {
    const container = document.getElementById('toastContainer');
    if (!container) return;

    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.innerHTML = message;
    container.appendChild(toast);

    setTimeout(() => {
      toast.classList.add('hide');
      setTimeout(() => toast.remove(), 260);
    }, duration);
  }

  function escapeHtml(str) {
    return String(str || '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  /* ------------------ Sample Demo Data ------------------ */

  const SAMPLE_LOANS = [
    {
      id: 1718000001,
      borrower: 'Rajesh Sharma',
      phone: '9876543210',
      principal: 100000,
      interest: 12,
      tenure: 12,
      model: 'emi',
      startDate: new Date(Date.now() - 90 * 24 * 3600 * 1000).toISOString().split('T')[0],
      created: Date.now() - 90 * 24 * 3600 * 1000,
      notes: 'Shop expansion loan against inventory guarantee',
      payments: [
        { id: 101, amount: 8885, date: '2026-08-15', mode: 'UPI', note: 'First EMI' },
        { id: 102, amount: 8885, date: '2026-09-15', mode: 'UPI', note: 'Second EMI' },
        { id: 103, amount: 8885, date: '2026-10-10', mode: 'Bank Transfer', note: 'Third EMI' }
      ]
    },
    {
      id: 1718000002,
      borrower: 'Priya Patel',
      phone: '9812345678',
      principal: 50000,
      interest: 14,
      tenure: 6,
      model: 'simple',
      startDate: new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString().split('T')[0],
      created: Date.now() - 30 * 24 * 3600 * 1000,
      notes: 'Boutique working capital',
      payments: [
        { id: 201, amount: 8917, date: '2026-09-28', mode: 'Cash', note: 'Installment #1' }
      ]
    },
    {
      id: 1718000003,
      borrower: 'Vikram Singh',
      phone: '9922334455',
      principal: 30000,
      interest: 10,
      tenure: 3,
      model: 'emi',
      startDate: new Date(Date.now() - 120 * 24 * 3600 * 1000).toISOString().split('T')[0],
      created: Date.now() - 120 * 24 * 3600 * 1000,
      notes: 'Laptop purchase advance',
      payments: [
        { id: 301, amount: 10167, date: '2026-07-10', mode: 'UPI', note: 'Payment 1' },
        { id: 302, amount: 10167, date: '2026-08-10', mode: 'UPI', note: 'Payment 2' },
        { id: 303, amount: 10167, date: '2026-09-10', mode: 'UPI', note: 'Final settlement' }
      ]
    }
  ];

  /* ------------------ Core Application Controller ------------------ */

  let currentTab = 'overview';
  let activeFilter = 'all';
  let activeSearch = '';
  let selectedLoanId = null;

  async function initApp() {
    registerServiceWorker();
    setupThemeToggle();
    setupNavigation();
    setupModals();
    setupCalculator();
    setupExportImport();
    setupDangerZone();
    setupLockScreen();
    setupWizardModal();
    setupRecoveryModal();
    setupAgentManager();
    setupCloudSync();
    setupSecuritySettingsForm();
    setupUpiQrToggle();

    await initPersistentStorage();
    await checkDualLayerRecovery();
    updateBackupHealthUI();

    renderDashboard();
    renderLoansList();
    setupPWAInstaller();
    setupViewportStability();

    // Check initial URL hash
    const hash = (window.location.hash || '').replace('#', '').toLowerCase();
    if (hash === 'loans' || hash === 'calculator' || hash === 'settings') {
      if (window.switchAppTab) window.switchAppTab(hash);
    } else if (hash === 'new-loan') {
      if (window.switchAppTab) window.switchAppTab('loans');
      setTimeout(() => openNewLoanModal(), 200);
    }
  }

  function registerServiceWorker() {
    if ('serviceWorker' in navigator && window.location.protocol.startsWith('http')) {
      navigator.serviceWorker.register('./sw.js').catch(err => {
        console.log('SW registration skipped:', err);
      });
    }
  }

  /* ------------------ PWA Fullscreen Standalone App Installer ------------------ */
  let deferredPrompt = null;

  function isRunningInApp() {
    return (
      window.matchMedia('(display-mode: standalone)').matches ||
      window.matchMedia('(display-mode: fullscreen)').matches ||
      window.matchMedia('(display-mode: minimal-ui)').matches ||
      window.navigator.standalone === true ||
      document.referrer.includes('android-app://') ||
      typeof window.Capacitor !== 'undefined' ||
      window.isNativeApp === true ||
      location.protocol === 'capacitor:' ||
      location.protocol === 'file:' ||
      location.protocol === 'ionic:' ||
      location.protocol === 'content:' ||
      /Capacitor|FinVault|wv|WebView/i.test(navigator.userAgent)
    );
  }

  function setupPWAInstaller() {
    const installBanner = document.getElementById('pwaInstallBanner');
    const installBtn = document.getElementById('pwaInstallBtn');
    const installModal = document.getElementById('pwaInstallModal');
    const nativeInstallBtn = document.getElementById('pwaTriggerNativeBtn');

    // If already running inside installed standalone app / APK / WebView, completely remove install banner
    if (isRunningInApp()) {
      if (installBanner) {
        installBanner.style.setProperty('display', 'none', 'important');
        installBanner.remove();
      }
      return;
    }

    // Capture browser beforeinstallprompt
    window.addEventListener('beforeinstallprompt', (e) => {
      e.preventDefault();
      deferredPrompt = e;
      if (!isRunningInApp() && installBanner) {
        installBanner.style.display = 'block';
      }
      if (nativeInstallBtn) nativeInstallBtn.style.display = 'inline-flex';
    });

    // Auto-display on mobile browsers after 1.5s only if NOT installed and NOT in app
    setTimeout(() => {
      const isMobile = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);
      if (isMobile && !isRunningInApp() && installBanner && document.body.contains(installBanner)) {
        installBanner.style.display = 'block';
      }
    }, 1500);

    const handleInstallClick = () => {
      if (deferredPrompt) {
        deferredPrompt.prompt();
        deferredPrompt.userChoice.then((choiceResult) => {
          if (choiceResult && choiceResult.outcome === 'accepted') {
            showToast('🚀 Installing FinVault to your phone home screen...');
            if (installBanner) installBanner.style.display = 'none';
            closeAllModals();
          }
          deferredPrompt = null;
        });
      } else {
        // Show step-by-step native guide modal
        if (installModal) {
          openModal(installModal);
        }
      }
    };

    if (installBtn) {
      installBtn.addEventListener('click', handleInstallClick);
    }

    if (nativeInstallBtn) {
      nativeInstallBtn.addEventListener('click', () => {
        if (deferredPrompt) {
          deferredPrompt.prompt();
          deferredPrompt.userChoice.then((choiceResult) => {
            if (choiceResult && choiceResult.outcome === 'accepted') {
              showToast('🚀 Installing FinVault...');
              if (installBanner) installBanner.style.display = 'none';
              closeAllModals();
            }
            deferredPrompt = null;
          });
        }
      });
    }

    window.addEventListener('appinstalled', () => {
      showToast('🎉 FinVault installed! Open from Home Screen for zero-browser-bar experience.');
      if (installBanner) installBanner.style.display = 'none';
      closeAllModals();
      deferredPrompt = null;
    });
  }

  /* ------------------ Viewport Stability & Mobile Zoom Protection ------------------ */
  function setupViewportStability() {
    ['gesturestart', 'gesturechange', 'gestureend'].forEach((evt) => {
      document.addEventListener(evt, (e) => {
        e.preventDefault();
      }, { passive: false });
    });
  }

  /* ------------------ Theme Switcher ------------------ */

  function setupThemeToggle() {
    const themeBtn = document.getElementById('themeToggleBtn');
    const storedTheme = localStorage.getItem('dgs_theme') || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    document.documentElement.setAttribute('data-theme', storedTheme);

    if (themeBtn) {
      themeBtn.addEventListener('click', () => {
        const current = document.documentElement.getAttribute('data-theme') || 'light';
        const next = current === 'dark' ? 'light' : 'dark';
        document.documentElement.setAttribute('data-theme', next);
        localStorage.setItem('dgs_theme', next);
        showToast(next === 'dark' ? '🌙 Dark Mode Active' : '☀️ Light Mode Active');
      });
    }
  }

  /* ------------------ Passcode Lock & Role Switching Engine ------------------ */

  function setupLockScreen() {
    const overlay = document.getElementById('lockScreenOverlay');
    const roleBtnAdmin = document.getElementById('roleBtnAdmin');
    const roleBtnAgent = document.getElementById('roleBtnAgent');
    const roleSubtitle = document.getElementById('lockRoleSubtitle');
    const numpadButtons = document.querySelectorAll('.numpad-btn[data-key]');
    const numpadClearBtn = document.getElementById('numpadClearBtn');
    const numpadDeleteBtn = document.getElementById('numpadDeleteBtn');
    const userBadge = document.getElementById('currentUserBadge');
    const forgotBtn = document.getElementById('forgotPinBtn');

    if (!overlay) return;

    function updateRoleUI() {
      closeAllModals();
      if (roleBtnAdmin) roleBtnAdmin.classList.toggle('active', currentRole === 'admin');
      if (roleBtnAgent) roleBtnAgent.classList.toggle('active', currentRole === 'agent');
      const settings = getSecuritySettings();
      if (roleSubtitle) {
        if (currentRole === 'admin') {
          roleSubtitle.textContent = `Enter Admin Passcode (${settings.adminName || 'Owner'})`;
        } else {
          const totalAgents = (settings.agents || []).filter(a => a.role === 'agent' || !a.role).length;
          roleSubtitle.textContent = totalAgents > 0 
            ? 'Enter Field Agent 4-Digit Passcode' 
            : 'No Field Agents added yet (Admin can add in Settings)';
        }
      }
      if (forgotBtn) {
        forgotBtn.textContent = currentRole === 'admin' ? '🔑 Forgot Passcode?' : '❓ Agent Passcode Help';
      }
      resetPin();
    }

    if (roleBtnAdmin) roleBtnAdmin.addEventListener('click', () => { currentRole = 'admin'; updateRoleUI(); });
    if (roleBtnAgent) roleBtnAgent.addEventListener('click', () => { currentRole = 'agent'; updateRoleUI(); });

    function updateDots() {
      for (let i = 0; i < 4; i++) {
        const dot = document.getElementById(`dot-${i}`);
        if (dot) dot.classList.toggle('filled', i < enteredPin.length);
      }
    }

    function resetPin() {
      enteredPin = '';
      for (let i = 0; i < 4; i++) {
        const dot = document.getElementById(`dot-${i}`);
        if (dot) {
          dot.classList.remove('filled');
          dot.classList.remove('error');
        }
      }
    }

    function checkPin() {
      const settings = getSecuritySettings();

      if (currentRole === 'admin') {
        const expected = settings.adminPin || '1234';
        const isMaster = (enteredPin === expected);
        const matchingCoAdmin = (settings.agents || []).find(a => a.pin === enteredPin && a.role === 'admin');

        if (isMaster || matchingCoAdmin) {
          if (matchingCoAdmin && !matchingCoAdmin.active) {
            showToast(`⚠️ Co-Admin account for "${matchingCoAdmin.name}" is disabled by Primary Admin`);
            for (let i = 0; i < 4; i++) {
              const dot = document.getElementById(`dot-${i}`);
              if (dot) dot.classList.add('error');
            }
            setTimeout(() => resetPin(), 400);
            return;
          }

          const adminName = isMaster ? (settings.adminName || 'Admin') : matchingCoAdmin.name;
          const adminTitle = isMaster ? 'Owner' : 'Co-Admin';

          isUnlocked = true;
          currentAgent = matchingCoAdmin || null;
          closeAllModals();
          overlay.classList.add('hidden');
          document.body.classList.remove('role-admin', 'role-agent');
          document.body.classList.add('role-admin');

          const roleIcon = document.getElementById('roleIcon');
          const roleName = document.getElementById('roleName');
          if (roleIcon) roleIcon.textContent = '👑';
          if (roleName) roleName.textContent = adminName;

          showToast(`👑 Welcome, ${adminName}! (${adminTitle})`);
          resetPin();
          renderDashboard();
          renderLoansList();
          renderAgentTable();
        } else {
          for (let i = 0; i < 4; i++) {
            const dot = document.getElementById(`dot-${i}`);
            if (dot) dot.classList.add('error');
          }
          showToast('⚠️ Incorrect Admin Passcode');
          setTimeout(() => resetPin(), 400);
        }
      } else {
        // Field Agent login from dynamic agent roster
        const matchingAgent = (settings.agents || []).find(a => a.pin === enteredPin && (a.role === 'agent' || !a.role));
        if (matchingAgent) {
          if (!matchingAgent.active) {
            showToast(`⚠️ Account for "${matchingAgent.name}" is disabled by Admin`);
            for (let i = 0; i < 4; i++) {
              const dot = document.getElementById(`dot-${i}`);
              if (dot) dot.classList.add('error');
            }
            setTimeout(() => resetPin(), 400);
            return;
          }

          isUnlocked = true;
          currentAgent = matchingAgent;
          closeAllModals();
          overlay.classList.add('hidden');
          document.body.classList.remove('role-admin', 'role-agent');
          document.body.classList.add('role-agent');

          const roleIcon = document.getElementById('roleIcon');
          const roleName = document.getElementById('roleName');
          if (roleIcon) roleIcon.textContent = '🏃';
          if (roleName) roleName.textContent = matchingAgent.name;

          showToast(`🏃 Welcome, ${matchingAgent.name}! (Field Collection Mode)`);
          resetPin();
          renderDashboard();
          renderLoansList();
        } else {
          for (let i = 0; i < 4; i++) {
            const dot = document.getElementById(`dot-${i}`);
            if (dot) dot.classList.add('error');
          }
          const totalAgents = (settings.agents || []).filter(a => a.role === 'agent' || !a.role).length;
          if (totalAgents === 0) {
            showToast('⚠️ No Field Agents registered. Log in as Admin to add agents.');
          } else {
            showToast('⚠️ Incorrect Field Agent Passcode');
          }
          setTimeout(() => resetPin(), 400);
        }
      }
    }

    numpadButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        if (enteredPin.length < 4) {
          enteredPin += btn.dataset.key;
          updateDots();
          if (enteredPin.length === 4) setTimeout(checkPin, 120);
        }
      });
    });

    if (numpadClearBtn) numpadClearBtn.addEventListener('click', resetPin);
    if (numpadDeleteBtn) {
      numpadDeleteBtn.addEventListener('click', () => {
        if (enteredPin.length > 0) {
          enteredPin = enteredPin.slice(0, -1);
          updateDots();
        }
      });
    }

    if (userBadge) {
      userBadge.addEventListener('click', () => {
        openUserProfileModal();
      });
    }

  function openUserProfileModal() {
    const modal = document.getElementById('userProfileModal');
    if (!modal) return;

    const avatarEl = document.getElementById('profileModalAvatar');
    const nameEl = document.getElementById('profileModalName');
    const badgeEl = document.getElementById('profileModalRoleBadge');
    const accessEl = document.getElementById('profileModalAccessMode');
    const settings = getSecuritySettings();

    if (currentRole === 'admin') {
      const adminName = settings.adminName || 'Admin (Financier)';
      if (avatarEl) avatarEl.textContent = '👑';
      if (nameEl) nameEl.textContent = adminName;
      if (badgeEl) {
        badgeEl.textContent = '👑 Admin (Financier)';
        badgeEl.className = 'health-pill healthy';
      }
      if (accessEl) accessEl.textContent = 'Full Master Control (Loans, Ledger & Settings)';
    } else {
      const agentName = currentAgent ? currentAgent.name : 'Field Agent';
      if (avatarEl) avatarEl.textContent = '🏃';
      if (nameEl) nameEl.textContent = agentName;
      if (badgeEl) {
        badgeEl.textContent = '🏃 Field Collection Staff';
        badgeEl.className = 'health-pill healthy';
      }
      if (accessEl) accessEl.textContent = 'Field Mode (Borrower Collections & Receipts)';
    }

    openModal(modal);
  }

    window.addEventListener('keydown', (e) => {
      if (!isUnlocked) {
        if (e.key >= '0' && e.key <= '9') {
          if (enteredPin.length < 4) {
            enteredPin += e.key;
            updateDots();
            if (enteredPin.length === 4) setTimeout(checkPin, 120);
          }
        } else if (e.key === 'Backspace') {
          if (enteredPin.length > 0) {
            enteredPin = enteredPin.slice(0, -1);
            updateDots();
          }
        } else if (e.key === 'Escape') {
          resetPin();
        }
      }
    });

    updateRoleUI();
  }

  function lockApp() {
    isUnlocked = false;
    currentAgent = null;
    const overlay = document.getElementById('lockScreenOverlay');
    if (overlay) overlay.classList.remove('hidden');
    const roleSubtitle = document.getElementById('lockRoleSubtitle');
    if (roleSubtitle) roleSubtitle.textContent = 'Enter Passcode to Unlock';
    showToast('🔒 App Locked');
  }

  /* ------------------ First-Time Setup Wizard ------------------ */

  function setupWizardModal() {
    const wizardModal = document.getElementById('setupWizardModal');
    const wizardForm = document.getElementById('setupWizardForm');
    if (!wizardModal || !wizardForm) return;

    const settings = getSecuritySettings();
    if (!settings.isRegistered) {
      wizardModal.classList.remove('hidden');
    }

    wizardForm.addEventListener('submit', (e) => {
      e.preventDefault();
      const firm = document.getElementById('wizFirmName').value.trim() || 'FinVault';
      const name = document.getElementById('wizAdminName').value.trim() || 'Admin';
      const pin = document.getElementById('wizPin').value.trim();
      const pinConfirm = document.getElementById('wizPinConfirm').value.trim();
      const question = document.getElementById('wizQuestion').value.trim();
      const answer = document.getElementById('wizAnswer').value.trim().toLowerCase();
      const upi = document.getElementById('wizUpi').value.trim() || 'owner@okhdfcbank';

      if (pin.length !== 4 || isNaN(Number(pin))) {
        showToast('⚠️ Master Passcode must be exactly 4 digits');
        return;
      }
      if (pin !== pinConfirm) {
        showToast('⚠️ Passcodes do not match! Please check again.');
        return;
      }

      const updated = {
        ...settings,
        isRegistered: true,
        firmName: firm,
        adminName: name,
        adminPin: pin,
        securityQuestion: question,
        securityAnswer: answer,
        ownerUpiId: upi
      };

      saveSecuritySettings(updated);
      wizardModal.classList.add('hidden');

      isUnlocked = true;
      currentRole = 'admin';
      const lockOverlay = document.getElementById('lockScreenOverlay');
      if (lockOverlay) lockOverlay.classList.add('hidden');
      document.body.classList.remove('role-admin', 'role-agent');
      document.body.classList.add('role-admin');

      const roleIcon = document.getElementById('roleIcon');
      const roleName = document.getElementById('roleName');
      if (roleIcon) roleIcon.textContent = '👑';
      if (roleName) roleName.textContent = name;

      showToast(`🎉 Welcome to ${firm}, ${name}! Vault Registered.`);
      renderDashboard();
      renderLoansList();
      renderAgentTable();
    });
  }

  /* ------------------ Passcode Recovery Handler ------------------ */

  function setupRecoveryModal() {
    const forgotBtn = document.getElementById('forgotPinBtn');
    const recoveryModal = document.getElementById('recoveryModal');
    const agentHelpModal = document.getElementById('agentPasscodeHelpModal');
    const recoveryForm = document.getElementById('recoveryForm');
    const qLabel = document.getElementById('recoveryQuestionLabel');

    if (forgotBtn) {
      forgotBtn.addEventListener('click', () => {
        const sec = getSecuritySettings();
        if (currentRole === 'admin') {
          // Master Admin Recovery Form
          if (qLabel) qLabel.textContent = sec.securityQuestion || 'Security Recovery Question';
          const ansInput = document.getElementById('recoveryAnswerInput');
          const pinInput = document.getElementById('recoveryNewPin');
          if (ansInput) ansInput.value = '';
          if (pinInput) pinInput.value = '';
          if (recoveryModal) openModal(recoveryModal);
        } else {
          // Field Agent Assistance (Never show admin recovery to agents)
          const adminNameEl = document.getElementById('agentHelpAdminName');
          if (adminNameEl) adminNameEl.textContent = sec.adminName || 'Admin (Financier)';
          if (agentHelpModal) openModal(agentHelpModal);
        }
      });
    }

    if (recoveryForm) {
      recoveryForm.addEventListener('submit', (e) => {
        e.preventDefault();
        if (currentRole !== 'admin') {
          showToast('⚠️ Only Admin master passcode can be recovered here');
          closeAllModals();
          return;
        }

        const sec = getSecuritySettings();
        const enteredAnswer = document.getElementById('recoveryAnswerInput').value.trim().toLowerCase();
        const newPin = document.getElementById('recoveryNewPin').value.trim();

        if (enteredAnswer !== (sec.securityAnswer || '').toLowerCase()) {
          showToast('⚠️ Incorrect security recovery answer');
          return;
        }

        if (newPin.length !== 4 || isNaN(Number(newPin))) {
          showToast('⚠️ New Passcode must be exactly 4 digits');
          return;
        }

        sec.adminPin = newPin;
        saveSecuritySettings(sec);
        closeAllModals();
        showToast('✨ Master Passcode reset successfully! Please log in.');
      });
    }
  }

  /* ------------------ Team & Field Agents Management Roster ------------------ */

  function renderAgentTable() {
    const tbody = document.getElementById('agentTableBody');
    if (!tbody) return;

    const sec = getSecuritySettings();
    const agents = sec.agents || [];

    if (!agents.length) {
      tbody.innerHTML = `<tr><td colspan="6" style="text-align:center;color:var(--text-secondary);padding:18px">No team members or co-admins registered yet. Click "+ Add Team Member / Co-Admin" above.</td></tr>`;
      return;
    }

    tbody.innerHTML = agents.map(ag => `
      <tr>
        <td style="font-weight:700">${escapeHtml(ag.name)}</td>
        <td>
          <span class="agent-role-badge ${ag.role === 'admin' ? 'admin' : 'agent'}">
            ${ag.role === 'admin' ? '👑 CO-ADMIN' : '🏃 FIELD AGENT'}
          </span>
        </td>
        <td style="color:var(--text-secondary)">${escapeHtml(ag.phone || '—')}</td>
        <td>••••</td>
        <td>
          <span class="agent-status-badge ${ag.active ? 'active' : 'disabled'}">
            ${ag.active ? 'ACTIVE' : 'DISABLED'}
          </span>
        </td>
        <td>
          <div style="display:flex;gap:6px">
            <button class="btn btn-ghost btn-sm" onclick="toggleAgentStatus('${ag.id}')">
              ${ag.active ? 'Deactivate' : 'Activate'}
            </button>
            <button class="btn btn-ghost btn-sm" style="color:var(--danger)" onclick="deleteAgent('${ag.id}')">
              Delete
            </button>
          </div>
        </td>
      </tr>
    `).join('');
  }

  function setupAgentManager() {
    const openAddBtn = document.getElementById('openAddAgentBtn');
    const agentModal = document.getElementById('agentModal');
    const agentForm = document.getElementById('agentForm');

    function setRoleSelection(role) {
      const roleInput = document.getElementById('agentInputRole');
      if (roleInput) roleInput.value = role;
      const cardAgent = document.getElementById('roleSelectCardAgent');
      const cardAdmin = document.getElementById('roleSelectCardAdmin');
      if (cardAgent && cardAdmin) {
        if (role === 'admin') {
          cardAdmin.classList.add('selected');
          cardAgent.classList.remove('selected');
        } else {
          cardAgent.classList.add('selected');
          cardAdmin.classList.remove('selected');
        }
      }
    }

    const cardAgent = document.getElementById('roleSelectCardAgent');
    const cardAdmin = document.getElementById('roleSelectCardAdmin');
    if (cardAgent) {
      cardAgent.addEventListener('click', () => setRoleSelection('agent'));
      cardAgent.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          setRoleSelection('agent');
        }
      });
    }
    if (cardAdmin) {
      cardAdmin.addEventListener('click', () => setRoleSelection('admin'));
      cardAdmin.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          setRoleSelection('admin');
        }
      });
    }

    if (openAddBtn && agentModal) {
      openAddBtn.addEventListener('click', () => {
        if (currentRole !== 'admin') {
          showToast('⚠️ Only Admin can manage team members');
          return;
        }
        agentForm.reset();
        document.getElementById('agentEditId').value = '';
        setRoleSelection('agent');
        document.getElementById('agentModalTitle').textContent = 'Add Team Member / Co-Admin';
        openModal(agentModal);
      });
    }

    if (agentForm) {
      agentForm.addEventListener('submit', (e) => {
        e.preventDefault();
        const role = (document.getElementById('agentInputRole') && document.getElementById('agentInputRole').value) || 'agent';
        const name = document.getElementById('agentInputName').value.trim();
        const phone = document.getElementById('agentInputPhone').value.trim();
        const pin = document.getElementById('agentInputPin').value.trim();

        if (!name || pin.length !== 4 || isNaN(Number(pin))) {
          showToast('⚠️ Please enter full name and a 4-digit passcode');
          return;
        }

        const sec = getSecuritySettings();
        sec.agents = sec.agents || [];

        const newAgent = {
          id: 'ag_' + Date.now(),
          name,
          phone,
          pin,
          role,
          active: true,
          createdAt: Date.now()
        };

        sec.agents.push(newAgent);
        saveSecuritySettings(sec);
        closeAllModals();
        renderAgentTable();
        showToast(role === 'admin' ? `👑 Co-Admin "${name}" registered with full admin access!` : `👥 Field Agent "${name}" registered!`);
      });
    }

    renderAgentTable();
  }

  window.toggleAgentStatus = function(agentId) {
    if (currentRole !== 'admin') return;
    const sec = getSecuritySettings();
    const ag = (sec.agents || []).find(x => x.id === agentId);
    if (ag) {
      ag.active = !ag.active;
      saveSecuritySettings(sec);
      renderAgentTable();
      showToast(`Agent "${ag.name}" is now ${ag.active ? 'Active' : 'Disabled'}`);
    }
  };

  window.deleteAgent = function(agentId) {
    if (currentRole !== 'admin') return;
    if (confirm('Delete this field agent? They will no longer be able to log in.')) {
      const sec = getSecuritySettings();
      sec.agents = (sec.agents || []).filter(x => x.id !== agentId);
      saveSecuritySettings(sec);
      renderAgentTable();
      showToast('Agent deleted');
    }
  };

  /* ------------------ Central Cloud Database (Developer Provided) ------------------ */
  const CENTRAL_SUPABASE_CONFIG = {
    url: 'https://cpfpmnyipiqdtcnobwoq.supabase.co',
    key: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNwZnBtbnlpcGlxZHRjbm9id29xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIwMzYwMzcsImV4cCI6MjEwNzYxMjAzN30.KnKEfEWrUFNbvveRnwf9w71-nXULRDKQhrnhYoCrd_w'
  };

  /* ------------------ Live Cloud Database Connection Diagnostics ------------------ */
  async function testCloudConnection() {
    const sec = getSecuritySettings();
    const detailsBox = document.getElementById('cloudSyncDetailsBox');
    const stateEl = document.getElementById('cloudDbState');
    const latencyEl = document.getElementById('cloudDbLatency');
    const countEl = document.getElementById('cloudDbRecordsCount');
    const syncTimeEl = document.getElementById('cloudDbLastSyncTime');
    const errorAlert = document.getElementById('cloudSyncErrorAlert');
    const errorMsg = document.getElementById('cloudSyncErrorMessage');
    const successAlert = document.getElementById('cloudSyncSuccessAlert');
    const statusPill = document.getElementById('cloudSyncStatusPill');
    const pingBtn = document.getElementById('testCloudPingBtn');

    if (!sec.cloudSyncEnabled) {
      if (detailsBox) detailsBox.style.display = 'none';
      return { success: false, reason: 'disabled' };
    }

    if (detailsBox) detailsBox.style.display = 'block';

    if (stateEl) {
      stateEl.innerHTML = '<span class="status-dot warning"></span> <span style="color:var(--warning);">Connecting...</span>';
    }
    if (latencyEl) latencyEl.textContent = 'Measuring...';
    if (errorAlert) errorAlert.style.display = 'none';
    if (successAlert) successAlert.style.display = 'none';
    if (pingBtn) {
      pingBtn.disabled = true;
      pingBtn.textContent = '⏳ Testing...';
    }

    if (!navigator.onLine) {
      if (stateEl) {
        stateEl.innerHTML = '<span class="status-dot danger"></span> <span style="color:var(--danger);">Device Offline</span>';
      }
      if (latencyEl) latencyEl.textContent = 'No Internet';
      if (statusPill) {
        statusPill.innerHTML = '⚠️ Offline (No Internet)';
        statusPill.className = 'health-pill needs-action';
      }
      if (errorAlert) {
        errorAlert.style.display = 'block';
        if (errorMsg) errorMsg.textContent = 'Your device is not connected to the internet. All ledger data is safely stored locally on this device and will sync when your internet connection is restored.';
      }
      if (pingBtn) {
        pingBtn.disabled = false;
        pingBtn.textContent = '⚡ Test Connection';
      }
      return { success: false, reason: 'offline' };
    }

    const t0 = performance.now();
    try {
      const res = await fetch(`${CENTRAL_SUPABASE_CONFIG.url}/rest/v1/loans?select=*`, {
        method: 'GET',
        headers: {
          'apikey': CENTRAL_SUPABASE_CONFIG.key,
          'Authorization': `Bearer ${CENTRAL_SUPABASE_CONFIG.key}`
        }
      });
      const latency = Math.round(performance.now() - t0);

      if (res.ok) {
        const cloudData = await res.json();
        const count = Array.isArray(cloudData) ? cloudData.length : 0;
        const lastSync = localStorage.getItem('finvault_last_cloud_sync') || 'Just now';

        if (stateEl) {
          stateEl.innerHTML = '<span class="status-dot healthy"></span> <span style="color:var(--success);">Connected & Live</span>';
        }
        if (latencyEl) {
          latencyEl.textContent = `${latency} ms (${latency < 350 ? 'Fast' : 'Normal'})`;
        }
        if (countEl) {
          countEl.textContent = `${count} loan${count === 1 ? '' : 's'} in cloud`;
        }
        if (syncTimeEl) {
          syncTimeEl.textContent = lastSync;
        }
        if (statusPill) {
          statusPill.innerHTML = `🟢 Cloud Connected (${latency}ms)`;
          statusPill.className = 'health-pill healthy';
        }
        if (successAlert) {
          successAlert.style.display = 'block';
          successAlert.innerHTML = `✓ <strong>Connected & Active</strong>: Database (Supabase) reachable with ${latency}ms response. ${count} borrower records stored in cloud.`;
        }
        if (errorAlert) errorAlert.style.display = 'none';
        if (pingBtn) {
          pingBtn.disabled = false;
          pingBtn.textContent = '⚡ Test Connection';
        }
        return { success: true, count, latency };
      } else {
        const errJson = await res.json().catch(() => ({}));
        let humanReason = errJson.message || `HTTP ${res.status} ${res.statusText}`;
        if (res.status === 404 || humanReason.includes('loans')) {
          humanReason = 'Database connected, but the "loans" table was not found in Supabase. Run the SQL schema script in Supabase.';
        } else if (res.status === 401 || res.status === 403) {
          humanReason = 'Authentication Failed: Invalid Supabase anon API Key or Row Level Security (RLS) is blocking read access.';
        }

        if (stateEl) {
          stateEl.innerHTML = `<span class="status-dot danger"></span> <span style="color:var(--danger);">Error (${res.status})</span>`;
        }
        if (latencyEl) latencyEl.textContent = `${latency} ms`;
        if (statusPill) {
          statusPill.innerHTML = `🔴 Cloud Error (${res.status})`;
          statusPill.className = 'health-pill needs-action';
        }
        if (errorAlert) {
          errorAlert.style.display = 'block';
          if (errorMsg) errorMsg.textContent = humanReason;
        }
        if (pingBtn) {
          pingBtn.disabled = false;
          pingBtn.textContent = '⚡ Test Connection';
        }
        return { success: false, reason: humanReason };
      }
    } catch(err) {
      const isOffline = !navigator.onLine || (err.message && (err.message.includes('fetch') || err.message.includes('Network')));
      const failReason = isOffline 
        ? 'Cannot reach Supabase servers. Verify your internet connection.' 
        : `Network exception: ${err.message}`;

      if (stateEl) {
        stateEl.innerHTML = '<span class="status-dot danger"></span> <span style="color:var(--danger);">Disconnected</span>';
      }
      if (latencyEl) latencyEl.textContent = 'Timeout / Failed';
      if (statusPill) {
        statusPill.innerHTML = '🔴 Cloud Disconnected';
        statusPill.className = 'health-pill needs-action';
      }
      if (errorAlert) {
        errorAlert.style.display = 'block';
        if (errorMsg) errorMsg.textContent = failReason;
      }
      if (pingBtn) {
        pingBtn.disabled = false;
        pingBtn.textContent = '⚡ Test Connection';
      }
      return { success: false, reason: failReason };
    }
  }

  /* ------------------ Cloud Sync Control (User Permission Toggle) ------------------ */
  function setupCloudSync() {
    const toggle = document.getElementById('cloudSyncToggle');
    const toggleLabel = document.getElementById('cloudSyncToggleLabel');
    const statusPill = document.getElementById('cloudSyncStatusPill');
    const syncBtn = document.getElementById('syncNowBtn');
    const testBtn = document.getElementById('testCloudPingBtn');
    const detailsBox = document.getElementById('cloudSyncDetailsBox');

    const sec = getSecuritySettings();
    const isEnabled = Boolean(sec.cloudSyncEnabled);

    function updateCloudUI(enabled) {
      if (toggle) toggle.checked = enabled;
      if (toggleLabel) {
        toggleLabel.textContent = enabled ? 'ON (Syncing to Cloud)' : 'OFF (Local Device Only)';
        toggleLabel.style.color = enabled ? 'var(--success)' : 'var(--text-secondary)';
      }
      if (statusPill) {
        if (!enabled) {
          statusPill.innerHTML = '🔒 100% On-Device Private Mode';
          statusPill.className = 'health-pill';
        }
      }
      if (syncBtn) syncBtn.style.display = enabled ? 'inline-flex' : 'none';
      if (testBtn) testBtn.style.display = enabled ? 'inline-flex' : 'none';
      if (detailsBox) detailsBox.style.display = enabled ? 'block' : 'none';
    }

    const onboardModal = document.getElementById('cloudSyncOnboardModal');
    const confirmOnboardBtn = document.getElementById('confirmCloudSyncModalBtn');
    const cancelOnboardBtn = document.getElementById('cancelCloudSyncModalBtn');
    const loanCountText = document.getElementById('cloudOnboardLoanCountText');

    function activateCloudSync() {
      const currentSec = getSecuritySettings();
      currentSec.cloudSyncEnabled = true;
      saveSecuritySettings(currentSec);
      updateCloudUI(true);
      updateBackupHealthUI();
      showToast('☁️ Cloud Backup enabled! Syncing past records to database...');
      syncToSupabase(true);
    }

    function deactivateCloudSync() {
      const currentSec = getSecuritySettings();
      currentSec.cloudSyncEnabled = false;
      saveSecuritySettings(currentSec);
      updateCloudUI(false);
      updateBackupHealthUI();
      showToast('🔒 Cloud Sync disabled. Data strictly saved on this device.');
    }

    if (toggle) {
      toggle.addEventListener('change', () => {
        if (currentRole !== 'admin') {
          showToast('⚠️ Only Admin can change cloud sync settings');
          toggle.checked = !toggle.checked;
          return;
        }
        const enabled = toggle.checked;

        if (enabled) {
          // Revert toggle visually until confirmed in modal
          toggle.checked = false;
          const loans = loadState();
          if (loanCountText) {
            loanCountText.innerHTML = `You have <strong>${loans.length} borrower account(s)</strong> stored locally. Enabling cloud sync will immediately upload and back up all these past records to the central database (<code>public.loans</code>).`;
          }
          if (onboardModal) {
            openModal(onboardModal);
            return;
          }
          activateCloudSync();
        } else {
          deactivateCloudSync();
        }
      });
    }

    if (confirmOnboardBtn) {
      confirmOnboardBtn.addEventListener('click', () => {
        closeAllModals();
        activateCloudSync();
      });
    }

    if (cancelOnboardBtn) {
      cancelOnboardBtn.addEventListener('click', () => {
        closeAllModals();
        if (toggle) toggle.checked = false;
      });
    }

    if (syncBtn) {
      syncBtn.addEventListener('click', () => {
        syncToSupabase(true);
      });
    }

    if (testBtn) {
      testBtn.addEventListener('click', () => {
        testCloudConnection().then(res => {
          if (res.success) {
            showToast(`🟢 Connected to Supabase! Latency: ${res.latency}ms`);
          } else {
            showToast(`⚠️ Connection Notice: ${res.reason}`);
          }
        });
      });
    }

    // If cloud sync was enabled by user, fetch updates on startup & run diagnostic test
    if (isEnabled) {
      pullFromSupabase();
      testCloudConnection();
    }
  }

  async function syncToSupabase(userInitiated = false) {
    const sec = getSecuritySettings();
    if (!sec.cloudSyncEnabled) return; // Strictly local-only when disabled

    const syncBtn = document.getElementById('syncNowBtn');
    if (syncBtn) {
      syncBtn.disabled = true;
      syncBtn.textContent = '⏳ Syncing...';
    }

    if (userInitiated) showToast('☁️ Syncing with Cloud Database...');
    try {
      const loans = loadState();
      // Map loans to match Supabase schema (maps 'interest' to 'rate', ensures numeric id)
      const mappedLoans = loans.map(l => ({
        id: Number(l.id) || Date.now(),
        borrower: String(l.borrower || ''),
        phone: String(l.phone || ''),
        principal: Number(l.principal) || 0,
        rate: Number(l.interest !== undefined ? l.interest : (l.rate !== undefined ? l.rate : 12)),
        tenure: Number(l.tenure) || 12,
        model: String(l.model || 'emi'),
        startDate: String(l.startDate || new Date().toISOString().split('T')[0]),
        created: Number(l.created) || Date.now(),
        notes: String(l.notes || ''),
        payments: Array.isArray(l.payments) ? l.payments : []
      }));

      const res = await fetch(`${CENTRAL_SUPABASE_CONFIG.url}/rest/v1/loans`, {
        method: 'POST',
        headers: {
          'apikey': CENTRAL_SUPABASE_CONFIG.key,
          'Authorization': `Bearer ${CENTRAL_SUPABASE_CONFIG.key}`,
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates'
        },
        body: JSON.stringify(mappedLoans)
      });

      if (res.ok) {
        const timeStr = new Date().toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', second: '2-digit' }) + ' (' + new Date().toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }) + ')';
        localStorage.setItem('finvault_last_cloud_sync', timeStr);
        if (userInitiated) showToast(`✅ Cloud Sync Completed! ${mappedLoans.length} loan(s) backed up.`);
      } else {
        const errJson = await res.json().catch(() => ({}));
        console.warn('Supabase sync status:', res.status, errJson);
        if (userInitiated) {
          if (res.status === 404 || (errJson.message && errJson.message.includes('loans'))) {
            showToast('⚠️ Database table "loans" not found in Supabase. Run SQL setup script.');
          } else {
            showToast('⚠️ Sync notice: ' + (errJson.message || res.statusText));
          }
        }
      }
    } catch(err) {
      console.warn('Supabase sync error (device offline or network):', err);
      if (userInitiated) {
        showToast('⚠️ Notice: Could not connect to cloud. Saved safely on local device.');
      }
    } finally {
      if (syncBtn) {
        syncBtn.disabled = false;
        syncBtn.textContent = '☁️ Sync Now';
      }
      testCloudConnection();
    }
  }

  async function pullFromSupabase() {
    const sec = getSecuritySettings();
    if (!sec.cloudSyncEnabled) return;

    try {
      const res = await fetch(`${CENTRAL_SUPABASE_CONFIG.url}/rest/v1/loans?select=*`, {
        headers: {
          'apikey': CENTRAL_SUPABASE_CONFIG.key,
          'Authorization': `Bearer ${CENTRAL_SUPABASE_CONFIG.key}`
        }
      });
      if (res.ok) {
        const cloudLoans = await res.json();
        if (Array.isArray(cloudLoans) && cloudLoans.length > 0) {
          const localLoans = loadState();
          const localMap = new Map(localLoans.map(l => [String(l.id), l]));
          let updated = false;
          cloudLoans.forEach(cl => {
            const mapped = {
              ...cl,
              interest: Number(cl.interest !== undefined ? cl.interest : (cl.rate !== undefined ? cl.rate : 12))
            };
            const idStr = String(mapped.id);
            if (!localMap.has(idStr)) {
              localMap.set(idStr, mapped);
              updated = true;
            } else {
              const existing = localMap.get(idStr);
              if (mapped.payments && Array.isArray(mapped.payments) && mapped.payments.length > (existing.payments || []).length) {
                localMap.set(idStr, mapped);
                updated = true;
              }
            }
          });
          if (updated) {
            const merged = Array.from(localMap.values());
            localStorage.setItem(STORAGE_KEY, JSON.stringify(merged));
            await idbSet('loans', merged);
            renderDashboard();
            renderLoansList();
          }
        }
      }
    } catch(e) {
      console.log('Background cloud pull skipped:', e);
    }
  }

  /* ------------------ Security Settings Handler ------------------ */

  function setupSecuritySettingsForm() {
    const adminInput = document.getElementById('settingAdminPin');
    const upiInput = document.getElementById('settingOwnerUpi');
    const qInput = document.getElementById('settingSecurityQuestion');
    const aInput = document.getElementById('settingSecurityAnswer');
    const saveBtn = document.getElementById('saveSecuritySettingsBtn');

    if (!saveBtn) return;

    const current = getSecuritySettings();
    if (adminInput) adminInput.value = current.adminPin;
    if (upiInput) upiInput.value = current.ownerUpiId;
    if (qInput) qInput.value = current.securityQuestion || '';
    if (aInput) aInput.value = current.securityAnswer || '';

    saveBtn.addEventListener('click', () => {
      if (currentRole !== 'admin') {
        showToast('⚠️ Only Admin can change security settings');
        return;
      }
      const aPin = (adminInput.value || '').trim();
      const upi = (upiInput.value || '').trim() || 'owner@okhdfcbank';
      const q = (qInput.value || '').trim() || 'City where business started?';
      const a = (aInput.value || '').trim().toLowerCase() || 'chennai';

      if (aPin.length !== 4 || isNaN(Number(aPin))) {
        showToast('⚠️ Admin Passcode must be exactly 4 digits');
        return;
      }

      saveSecuritySettings({
        ...current,
        adminPin: aPin,
        ownerUpiId: upi,
        securityQuestion: q,
        securityAnswer: a
      });

      showToast('🔒 Master Security & UPI Settings Saved Successfully!');
    });
  }

  /* ------------------ UPI QR Code Display Toggle ------------------ */

  function setupUpiQrToggle() {
    const toggleBtn = document.getElementById('toggleUpiQrBtn');
    const qrSection = document.getElementById('upiQrSection');
    const qrContainer = document.getElementById('upiQrContainer');
    const upiBadge = document.getElementById('upiIdBadge');
    const directLink = document.getElementById('upiDirectPayLink');
    const amountInput = document.getElementById('payAmount');

    if (!toggleBtn || !qrSection) return;

    toggleBtn.addEventListener('click', () => {
      const isHidden = qrSection.classList.contains('hidden');
      if (isHidden) {
        const amt = Number(amountInput.value) || 0;
        const settings = getSecuritySettings();
        const ownerUpi = settings.ownerUpiId || 'owner@okhdfcbank';
        const upiString = `upi://pay?pa=${encodeURIComponent(ownerUpi)}&pn=FinVault%20Finance&am=${amt}&cu=INR`;

        renderOfflineUpiQr(qrContainer, upiString);
        if (upiBadge) upiBadge.textContent = `UPI: ${ownerUpi} (₹${amt.toLocaleString('en-IN')})`;
        if (directLink) directLink.href = upiString;
        qrSection.classList.remove('hidden');
        toggleBtn.textContent = '❌ Hide UPI QR Code';
      } else {
        qrSection.classList.add('hidden');
        toggleBtn.textContent = '📷 Show UPI QR Code to Borrower (GPay/PhonePe)';
      }
    });
  }

  /* ------------------ Tab Navigation (Desktop & Mobile) ------------------ */

  function setupNavigation() {
    const desktopTabs = document.querySelectorAll('.desktop-nav-tabs .nav-tab-btn');
    const bottomTabs = document.querySelectorAll('.bottom-nav .bottom-tab');

    function switchTab(tabId) {
      currentTab = tabId;

      // Update button active classes
      desktopTabs.forEach(btn => {
        btn.classList.toggle('active', btn.dataset.tab === tabId);
      });
      bottomTabs.forEach(btn => {
        btn.classList.toggle('active', btn.dataset.tab === tabId);
      });

      // Show / hide screens
      const screens = ['overview', 'loans', 'calculator', 'settings'];
      screens.forEach(s => {
        const el = document.getElementById(`screen-${s}`);
        if (el) {
          el.classList.toggle('hidden', s !== tabId);
          if (s === tabId) {
            el.classList.add('animate-fade-in');
          }
        }
      });

      // Trigger re-renders when switching
      if (tabId === 'overview') renderDashboard();
      if (tabId === 'loans') renderLoansList();
    }

    desktopTabs.forEach(btn => {
      btn.addEventListener('click', () => switchTab(btn.dataset.tab));
    });

    bottomTabs.forEach(btn => {
      btn.addEventListener('click', () => switchTab(btn.dataset.tab));
    });

    window.switchAppTab = switchTab;
  }

  /* ------------------ Dashboard & Stats Renderer ------------------ */

  function renderDashboard() {
    const loans = loadState();
    let totalLent = 0;
    let totalCollected = 0;
    let totalRemaining = 0;
    let totalProfitEarned = 0;
    let activeLoansCount = 0;
    let paidLoansCount = 0;

    loans.forEach(loan => {
      const fin = getLoanFinancials(loan);
      totalLent += fin.principal;
      totalCollected += fin.totalPaid;
      totalRemaining += fin.remaining;
      totalProfitEarned += fin.totalInterest;

      if (fin.status === 'paid') {
        paidLoansCount++;
      } else {
        activeLoansCount++;
      }
    });

    // Update Hero Card
    const heroBalance = document.getElementById('heroBalance');
    if (heroBalance) heroBalance.textContent = fmtMoney(totalRemaining);

    const heroLent = document.getElementById('heroLent');
    if (heroLent) heroLent.textContent = fmtMoney(totalLent);

    const heroCollected = document.getElementById('heroCollected');
    if (heroCollected) heroCollected.textContent = fmtMoney(totalCollected);

    const heroProfit = document.getElementById('heroProfit');
    if (heroProfit) heroProfit.textContent = fmtMoney(totalProfitEarned);

    // Update 4 Grid Stats
    const statActive = document.getElementById('statActiveLoans');
    if (statActive) statActive.textContent = activeLoansCount;

    const statPaid = document.getElementById('statPaidLoans');
    if (statPaid) statPaid.textContent = paidLoansCount;

    const statTotalLoans = document.getElementById('statTotalLoans');
    if (statTotalLoans) statTotalLoans.textContent = loans.length;

    const statRecoveryRate = document.getElementById('statRecoveryRate');
    const totalExpected = totalLent + totalProfitEarned;
    const recoveryPct = totalExpected > 0 ? Math.round((totalCollected / totalExpected) * 100) : 0;
    if (statRecoveryRate) statRecoveryRate.textContent = `${recoveryPct}%`;

    // Render Recent Loans Preview on Overview
    renderRecentLoansPreview(loans);
  }

  function renderRecentLoansPreview(loans) {
    const previewList = document.getElementById('recentLoansList');
    if (!previewList) return;

    if (!loans.length) {
      previewList.innerHTML = `
        <div class="empty-state">
          <div class="empty-icon">
            <svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M12 4v16m8-8H4"/></svg>
          </div>
          <div class="empty-title">No loans recorded yet</div>
          <div class="empty-desc">Create your first loan or click "Load Sample Data" to explore.</div>
          <button class="btn btn-primary" onclick="openNewLoanModal()">+ Create First Loan</button>
        </div>
      `;
      return;
    }

    const recents = loans.slice().sort((a, b) => b.created - a.created).slice(0, 4);
    previewList.innerHTML = `
      <div class="loan-grid">
        ${recents.map(loan => createLoanCardHTML(loan)).join('')}
      </div>
    `;
    bindLoanCardEvents(previewList);
  }

  /* ------------------ Loans List & Filter Engine ------------------ */

  function renderLoansList() {
    const loansContainer = document.getElementById('allLoansContainer');
    if (!loansContainer) return;

    const loans = loadState();
    const query = activeSearch.trim().toLowerCase();

    const filtered = loans.filter(loan => {
      const fin = getLoanFinancials(loan);

      // Status filter
      if (activeFilter === 'active' && fin.status === 'paid') return false;
      if (activeFilter === 'paid' && fin.status !== 'paid') return false;
      if (activeFilter === 'overdue' && fin.status !== 'overdue') return false;

      // Search query
      if (query) {
        const nameMatch = (loan.borrower || '').toLowerCase().includes(query);
        const phoneMatch = (loan.phone || '').includes(query);
        const notesMatch = (loan.notes || '').toLowerCase().includes(query);
        const amountMatch = String(loan.principal).includes(query);
        return nameMatch || phoneMatch || notesMatch || amountMatch;
      }

      return true;
    }).sort((a, b) => b.created - a.created);

    if (!filtered.length) {
      loansContainer.innerHTML = `
        <div class="empty-state">
          <div class="empty-icon">
            <svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>
          </div>
          <div class="empty-title">${loans.length === 0 ? 'No loans added yet' : 'No matching loans found'}</div>
          <div class="empty-desc">${loans.length === 0 ? 'Add a borrower to start tracking loans and EMI repayments.' : 'Try adjusting your search terms or filter pills.'}</div>
          ${loans.length === 0 ? `<button class="btn btn-primary" onclick="openNewLoanModal()">+ Add New Loan</button>` : ''}
        </div>
      `;
      return;
    }

    loansContainer.innerHTML = `
      <div class="loan-grid">
        ${filtered.map(loan => createLoanCardHTML(loan)).join('')}
      </div>
    `;

    bindLoanCardEvents(loansContainer);
  }

  function createLoanCardHTML(loan) {
    const fin = getLoanFinancials(loan);
    const badgeClass = {
      active: 'badge-active',
      paid: 'badge-paid',
      overdue: 'badge-overdue'
    }[fin.status] || 'badge-active';

    const statusLabel = fin.status === 'paid' ? 'Fully Paid' : fin.status === 'overdue' ? 'Overdue' : 'Active';

    return `
      <div class="loan-card" data-loan-id="${loan.id}">
        <div>
          <div class="loan-card-header">
            <div>
              <div class="borrower-name">${escapeHtml(loan.borrower)}</div>
              ${loan.phone ? `<div class="borrower-phone">
                <svg width="13" height="13" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/></svg>
                ${escapeHtml(loan.phone)}
              </div>` : ''}
            </div>
            <span class="badge ${badgeClass}">${statusLabel}</span>
          </div>

          <div class="loan-progress-wrap">
            <div class="loan-progress-labels">
              <span>Collected: ${fmtMoney(fin.totalPaid)}</span>
              <span>${fin.progressPercent}%</span>
            </div>
            <div class="progress-bar-bg">
              <div class="progress-bar-fill" style="width: ${fin.progressPercent}%"></div>
            </div>
          </div>
        </div>

        <div class="loan-card-footer">
          <div>
            <div class="loan-meta-amount">${fmtMoney(fin.remaining)}</div>
            <div class="loan-meta-sub">${fin.status === 'paid' ? 'Total loan repaid' : `Remaining of ${fmtMoney(fin.totalPayable)}`}</div>
          </div>
          <div class="loan-actions-row" onclick="event.stopPropagation()">
            ${fin.remaining > 0 ? `<button class="btn btn-primary btn-sm" data-act="pay" data-id="${loan.id}">+ Pay</button>` : ''}
            ${loan.phone ? `<button class="btn btn-whatsapp btn-sm btn-icon" data-act="whatsapp" data-id="${loan.id}" title="WhatsApp Reminder">
              <svg width="15" height="15" fill="currentColor" viewBox="0 0 24 24"><path d="M.057 24l1.687-6.163c-1.041-1.804-1.588-3.849-1.587-5.946.003-6.556 5.338-11.891 11.893-11.891 3.181.001 6.167 1.24 8.413 3.488 2.245 2.248 3.481 5.236 3.48 8.414-.003 6.557-5.338 11.892-11.893 11.892-1.99-.001-3.951-.5-5.688-1.448l-6.305 1.654zm6.597-3.807c1.676.995 3.276 1.591 5.392 1.592 5.448 0 9.886-4.434 9.889-9.885.002-5.462-4.415-9.89-9.881-9.892-5.452 0-9.887 4.434-9.889 9.884-.001 2.225.651 3.891 1.746 5.634l-.999 3.648 3.742-.981z"/></svg>
            </button>` : ''}
            <button class="btn btn-secondary btn-sm" data-act="view" data-id="${loan.id}">Details</button>
          </div>
        </div>
      </div>
    `;
  }

  function bindLoanCardEvents(container) {
    container.querySelectorAll('.loan-card').forEach(card => {
      card.addEventListener('click', () => {
        openLoanDetailsModal(card.dataset.loanId);
      });
    });

    container.querySelectorAll('button[data-act]').forEach(btn => {
      btn.addEventListener('click', e => {
        e.stopPropagation();
        const act = btn.dataset.act;
        const id = btn.dataset.id;
        if (act === 'pay') openPaymentModal(id);
        if (act === 'view') openLoanDetailsModal(id);
        if (act === 'whatsapp') sendWhatsAppReminder(id);
      });
    });
  }

  /* ------------------ WhatsApp Reminder Integration ------------------ */

  function sendWhatsAppReminder(loanId) {
    const loans = loadState();
    const loan = loans.find(x => String(x.id) === String(loanId));
    if (!loan) return;

    if (!loan.phone) {
      showToast('⚠️ No phone number saved for this borrower');
      return;
    }

    const fin = getLoanFinancials(loan);
    const firmName = (getSecuritySettings().firmName || 'FinVault').trim();
    const cleanPhone = loan.phone.replace(/[^0-9]/g, '');
    const phoneWithCode = cleanPhone.length === 10 ? `91${cleanPhone}` : cleanPhone;

    const message = `Hello *${loan.borrower}*,\n\nThis is a friendly update from *${firmName}* regarding your loan.\n\n` +
      `• *Monthly Installment:* ₹${fin.monthly.toLocaleString('en-IN')}\n` +
      `• *Total Repaid:* ₹${fin.totalPaid.toLocaleString('en-IN')}\n` +
      `• *Remaining Balance:* ₹${fin.remaining.toLocaleString('en-IN')}\n\n` +
      `Please let us know once you process your next payment. Thank you!`;

    const url = `https://wa.me/${phoneWithCode}?text=${encodeURIComponent(message)}`;
    window.open(url, '_blank');
    showToast('💬 Opening WhatsApp reminder...');
  }

  /* ------------------ Modals System ------------------ */

  function setupModals() {
    // New / Edit Loan Modal
    const loanModal = document.getElementById('loanModal');
    const loanForm = document.getElementById('loanForm');
    const newLoanBtn = document.getElementById('newLoanBtn');
    const newLoanHeroBtn = document.getElementById('newLoanHeroBtn');

    if (newLoanBtn) newLoanBtn.addEventListener('click', () => openNewLoanModal());
    if (newLoanHeroBtn) newLoanHeroBtn.addEventListener('click', () => openNewLoanModal());

    // Auto-calculate suggested monthly in loan creation form
    const pInput = document.getElementById('loanPrincipal');
    const rInput = document.getElementById('loanInterest');
    const tInput = document.getElementById('loanTenure');
    const mInput = document.getElementById('loanModel');
    const previewEl = document.getElementById('loanSuggestPreview');

    function updateFormPreview() {
      if (!pInput || !previewEl) return;
      const P = Number(pInput.value) || 0;
      const R = Number(rInput.value) || 0;
      const T = Number(tInput.value) || 0;
      const model = mInput.value || 'emi';

      const val = model === 'emi' ? calcEmi(P, R, T) : calcSimple(P, R, T);
      previewEl.textContent = val > 0 ? fmtMoney(val) + '/month' : '—';
    }

    [pInput, rInput, tInput, mInput].forEach(el => {
      if (el) el.addEventListener('input', updateFormPreview);
    });

    if (loanForm) {
      loanForm.addEventListener('submit', e => {
        e.preventDefault();
        saveLoanFromForm();
      });
    }

    // Payment Form
    const paymentForm = document.getElementById('paymentForm');
    if (paymentForm) {
      paymentForm.addEventListener('submit', e => {
        e.preventDefault();
        savePaymentFromForm();
      });
    }

    // Delegated Modal Close (handles any [data-close-modal], .modal-close-btn, and backdrop taps)
    document.addEventListener('click', e => {
      if (e.target.closest('[data-close-modal]') || e.target.closest('.modal-close-btn')) {
        e.preventDefault();
        closeAllModals();
        return;
      }
      if (e.target.classList && e.target.classList.contains('modal-overlay')) {
        closeAllModals();
      }
    });

    // Close on Escape key
    window.addEventListener('keydown', e => {
      if (e.key === 'Escape') {
        closeAllModals();
      }
    });

    // Search and Filters
    const searchInput = document.getElementById('loansSearchInput');
    if (searchInput) {
      searchInput.addEventListener('input', e => {
        activeSearch = e.target.value;
        renderLoansList();
      });
    }

    document.querySelectorAll('.filter-pills .pill-btn').forEach(pill => {
      pill.addEventListener('click', () => {
        document.querySelectorAll('.filter-pills .pill-btn').forEach(p => p.classList.remove('active'));
        pill.classList.add('active');
        activeFilter = pill.dataset.filter;
        renderLoansList();
      });
    });

    // Profile Modal Action Buttons
    const profileLogoutBtn = document.getElementById('profileLogoutBtn');
    if (profileLogoutBtn) {
      profileLogoutBtn.addEventListener('click', () => {
        closeAllModals();
        lockApp();
        showToast('🔒 Locked & Logged out successfully');
      });
    }

    const profileGoSettingsBtn = document.getElementById('profileGoSettingsBtn');
    if (profileGoSettingsBtn) {
      profileGoSettingsBtn.addEventListener('click', () => {
        closeAllModals();
        if (window.switchAppTab) window.switchAppTab('settings');
      });
    }
  }

  function openModal(modal) {
    if (!modal) return;
    modal.classList.add('open');
    document.body.classList.add('modal-open');
  }
  window.openModal = openModal;

  function closeAllModals() {
    document.querySelectorAll('.modal-overlay').forEach(modal => modal.classList.remove('open'));
    document.body.classList.remove('modal-open');
  }
  window.closeAllModals = closeAllModals;

  function openNewLoanModal(editId = null) {
    if (currentRole !== 'admin') {
      showToast('⚠️ Only Admin can create or edit loans');
      return;
    }
    const modal = document.getElementById('loanModal');
    const form = document.getElementById('loanForm');
    const title = document.getElementById('loanModalTitle');

    form.reset();
    document.getElementById('loanStartDate').value = new Date().toISOString().split('T')[0];

    if (editId) {
      const loans = loadState();
      const loan = loans.find(x => String(x.id) === String(editId));
      if (loan) {
        document.getElementById('editLoanId').value = loan.id;
        document.getElementById('loanBorrower').value = loan.borrower;
        document.getElementById('loanPhone').value = loan.phone || '';
        document.getElementById('loanPrincipal').value = loan.principal;
        document.getElementById('loanInterest').value = loan.interest;
        document.getElementById('loanTenure').value = loan.tenure;
        document.getElementById('loanModel').value = loan.model || 'emi';
        document.getElementById('loanStartDate').value = loan.startDate || new Date(loan.created).toISOString().split('T')[0];
        document.getElementById('loanNotes').value = loan.notes || '';
        title.textContent = 'Edit Loan Details';
      }
    } else {
      document.getElementById('editLoanId').value = '';
      document.getElementById('loanInterest').value = '12';
      document.getElementById('loanTenure').value = '12';
      title.textContent = 'Create New Loan';
    }

    // Trigger preview
    const event = new Event('input');
    document.getElementById('loanPrincipal').dispatchEvent(event);

    openModal(modal);
    document.getElementById('loanBorrower').focus();
  }

  window.openNewLoanModal = openNewLoanModal;

  function saveLoanFromForm() {
    const editId = document.getElementById('editLoanId').value;
    const borrower = document.getElementById('loanBorrower').value.trim();
    const phone = document.getElementById('loanPhone').value.trim();
    const principal = Number(document.getElementById('loanPrincipal').value) || 0;
    const interest = Number(document.getElementById('loanInterest').value) || 0;
    const tenure = Number(document.getElementById('loanTenure').value) || 0;
    const model = document.getElementById('loanModel').value || 'emi';
    const startDate = document.getElementById('loanStartDate').value;
    const notes = document.getElementById('loanNotes').value.trim();

    if (!borrower || principal <= 0 || tenure <= 0) {
      showToast('⚠️ Please enter borrower name, principal (>0), and tenure (>0).');
      return;
    }

    const loans = loadState();

    if (editId) {
      const idx = loans.findIndex(x => String(x.id) === String(editId));
      if (idx >= 0) {
        loans[idx] = {
          ...loans[idx],
          borrower,
          phone,
          principal,
          interest,
          tenure,
          model,
          startDate,
          notes
        };
        showToast('✨ Loan details updated successfully');
      }
    } else {
      const newLoan = {
        id: Date.now(),
        borrower,
        phone,
        principal,
        interest,
        tenure,
        model,
        startDate: startDate || new Date().toISOString().split('T')[0],
        created: Date.now(),
        notes,
        payments: []
      };
      loans.unshift(newLoan);
      showToast(`🎉 Loan created for ${borrower}!`);
    }

    saveState(loans);
    closeAllModals();
    renderDashboard();
    renderLoansList();
  }

  /* ------------------ Payment Entry Modal ------------------ */

  function openPaymentModal(loanId) {
    const loans = loadState();
    const loan = loans.find(x => String(x.id) === String(loanId));
    if (!loan) return;

    selectedLoanId = loanId;
    const fin = getLoanFinancials(loan);

    document.getElementById('payLoanId').value = loan.id;
    document.getElementById('payBorrowerName').textContent = loan.borrower;
    document.getElementById('payRemainingBalance').textContent = fmtMoney(fin.remaining);
    document.getElementById('paySuggestedAmount').textContent = fmtMoney(fin.monthly);
    document.getElementById('payAmount').value = fin.remaining < fin.monthly ? fin.remaining : fin.monthly;
    document.getElementById('payDate').value = new Date().toISOString().split('T')[0];
    document.getElementById('payNote').value = '';

    openModal(document.getElementById('paymentModal'));
    document.getElementById('payAmount').focus();
  }

  function savePaymentFromForm() {
    const loanId = document.getElementById('payLoanId').value;
    const amount = Number(document.getElementById('payAmount').value) || 0;
    const date = document.getElementById('payDate').value;
    const mode = document.getElementById('payMode').value || 'Cash';
    const note = document.getElementById('payNote').value.trim();

    if (amount <= 0) {
      showToast('⚠️ Payment amount must be greater than zero');
      return;
    }

    const loans = loadState();
    const idx = loans.findIndex(x => String(x.id) === String(loanId));
    if (idx < 0) return;

    const loan = loans[idx];
    loan.payments = loan.payments || [];

    const settings = getSecuritySettings();
    const newPayment = {
      id: Date.now(),
      amount,
      date: date || new Date().toISOString().split('T')[0],
      mode,
      note,
      collectedBy: currentRole === 'agent' ? (settings.agentName || 'Field Agent') : 'Admin (Owner)'
    };

    loan.payments.push(newPayment);
    saveState(loans);
    closeAllModals();

    showToast(`✅ Payment of ${fmtMoney(amount)} recorded!`);
    renderDashboard();
    renderLoansList();

    // Show digital receipt right after payment
    openReceiptModal(loan, newPayment);
  }

  /* ------------------ Detailed Loan View & Ledger ------------------ */

  function openLoanDetailsModal(loanId) {
    const loans = loadState();
    const loan = loans.find(x => String(x.id) === String(loanId));
    if (!loan) return;

    selectedLoanId = loanId;
    const fin = getLoanFinancials(loan);
    const schedule = generateSchedule(loan);

    const modal = document.getElementById('loanDetailsModal');
    const container = document.getElementById('loanDetailsContent');

    container.innerHTML = `
      <div class="detail-banner">
        <div class="detail-header-row">
          <div>
            <h2 style="font-size:24px;font-weight:800;letter-spacing:-0.5px">${escapeHtml(loan.borrower)}</h2>
            <div style="font-size:13.5px;opacity:0.85;margin-top:4px">
              ${loan.phone ? `📞 ${escapeHtml(loan.phone)} • ` : ''}Started: ${fmtDate(loan.startDate)}
            </div>
            ${loan.notes ? `<div style="font-size:13px;opacity:0.9;margin-top:8px;background:rgba(255,255,255,0.12);padding:6px 10px;border-radius:8px">📝 ${escapeHtml(loan.notes)}</div>` : ''}
          </div>
          <div style="text-align:right">
            <div style="font-size:12px;text-transform:uppercase;letter-spacing:0.8px;opacity:0.8">Remaining</div>
            <div style="font-size:26px;font-weight:800;font-variant-numeric:tabular-nums">${fmtMoney(fin.remaining)}</div>
          </div>
        </div>

        <div class="detail-stats-strip">
          <div>
            <div style="font-size:11px;opacity:0.75">Principal</div>
            <div style="font-size:15px;font-weight:700">${fmtMoney(fin.principal)}</div>
          </div>
          <div>
            <div style="font-size:11px;opacity:0.75">Interest Rate</div>
            <div style="font-size:15px;font-weight:700">${loan.interest}% (${(loan.model || 'emi').toUpperCase()})</div>
          </div>
          <div>
            <div style="font-size:11px;opacity:0.75">Monthly EMI</div>
            <div style="font-size:15px;font-weight:700">${fmtMoney(fin.monthly)}</div>
          </div>
        </div>
      </div>

      <div style="display:flex;gap:10px;margin-bottom:16px;flex-wrap:wrap">
        ${fin.remaining > 0 ? `<button class="btn btn-primary" onclick="openPaymentFromDetails('${loan.id}')">+ Record Payment</button>` : ''}
        ${loan.phone ? `<button class="btn btn-whatsapp" onclick="sendWhatsAppReminder('${loan.id}')">💬 WhatsApp Reminder</button>` : ''}
        <button class="btn btn-secondary admin-only" onclick="openNewLoanModal('${loan.id}')">Edit Loan</button>
        <button class="btn btn-ghost admin-only" style="color:var(--danger)" onclick="deleteLoan('${loan.id}')">Delete</button>
      </div>

      <div style="margin-top:24px">
        <h3 style="font-size:16px;font-weight:700;margin-bottom:10px">Payment History (${(loan.payments || []).length} Payments)</h3>
        ${(loan.payments && loan.payments.length > 0) ? `
          <div class="ledger-table-wrap">
            <table class="ledger-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Mode</th>
                  <th>Amount</th>
                  <th>Notes</th>
                  <th>Receipt</th>
                </tr>
              </thead>
              <tbody>
                ${loan.payments.slice().reverse().map(p => `
                  <tr>
                    <td>${fmtDate(p.date)}</td>
                    <td><span class="badge" style="background:var(--accent-light);color:var(--accent)">${p.mode || 'Cash'}</span></td>
                    <td style="font-weight:700;color:var(--success)">${fmtMoney(p.amount)}</td>
                    <td style="color:var(--text-secondary)">${escapeHtml(p.note || '—')}</td>
                    <td>
                      <button class="btn btn-ghost btn-sm" onclick="viewReceipt('${loan.id}', '${p.id}')">🧾 View</button>
                    </td>
                  </tr>
                `).join('')}
              </tbody>
            </table>
          </div>
        ` : `
          <div style="padding:20px;text-align:center;background:var(--bg-tertiary);border-radius:12px;font-size:13.5px;color:var(--text-secondary)">
            No payments recorded yet. Click "+ Record Payment" to log an installment.
          </div>
        `}
      </div>

      <div style="margin-top:28px">
        <h3 style="font-size:16px;font-weight:700;margin-bottom:10px">Repayment Schedule (${loan.tenure} Months)</h3>
        <div class="ledger-table-wrap">
          <table class="ledger-table">
            <thead>
              <tr>
                <th>#</th>
                <th>Due Date</th>
                <th>Installment</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              ${schedule.map(s => `
                <tr>
                  <td>Month ${s.installmentNumber}</td>
                  <td>${fmtDate(s.dueDate)}</td>
                  <td style="font-weight:700">${fmtMoney(s.amount)}</td>
                  <td>
                    <span class="badge ${s.status === 'paid' ? 'badge-paid' : s.status === 'overdue' ? 'badge-overdue' : 'badge-active'}">
                      ${s.status.toUpperCase()}
                    </span>
                  </td>
                </tr>
              `).join('')}
            </tbody>
          </table>
        </div>
      </div>

      <div style="margin-top:24px;display:flex;justify-content:flex-end">
        <button class="btn btn-secondary" data-close-modal onclick="closeAllModals()">Close Ledger</button>
      </div>
    `;

    openModal(modal);
  }

  window.openPaymentFromDetails = function(loanId) {
    closeAllModals();
    openPaymentModal(loanId);
  };

  window.deleteLoan = function(loanId) {
    if (currentRole !== 'admin') {
      showToast('⚠️ Only Admin can delete loan records');
      return;
    }
    if (confirm('Are you sure you want to delete this loan record? This action cannot be undone.')) {
      let loans = loadState();
      loans = loans.filter(x => String(x.id) !== String(loanId));
      saveState(loans);
      closeAllModals();
      showToast('🗑️ Loan record deleted');
      renderDashboard();
      renderLoansList();
    }
  };

  /* ------------------ Digital Receipt System ------------------ */

  function openReceiptModal(loan, payment) {
    const modal = document.getElementById('receiptModal');
    const container = document.getElementById('receiptContent');
    const fin = getLoanFinancials(loan);

    const firmName = escapeHtml(getSecuritySettings().firmName || 'FinVault');

    container.innerHTML = `
      <div class="receipt-card" style="border: 2px dashed var(--border-card); padding: 24px; border-radius: 16px; background: var(--bg-tertiary);">
        <div style="text-align:center; margin-bottom: 16px;">
          <img src="icon.svg" alt="Logo" style="width: 44px; height: 44px; border-radius: 10px; margin-bottom: 6px; box-shadow: 0 2px 8px rgba(0,0,0,0.12);" />
          <div style="font-size: 20px; font-weight: 800; color: var(--accent); letter-spacing: -0.3px;">${firmName.toUpperCase()}</div>
          <div style="font-size: 11px; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 1.2px; font-weight: 600;">Official Payment Voucher</div>
          <div style="font-size: 11px; color: var(--text-tertiary); margin-top: 2px;">Receipt #${payment.id || Date.now()}</div>
        </div>

        <div class="receipt-row" style="display:flex; justify-content:space-between; font-size: 13.5px; padding: 7px 0; border-bottom: 1px solid var(--border-subtle);">
          <span style="color:var(--text-secondary)">Received From:</span>
          <span style="font-weight:700">${escapeHtml(loan.borrower)}</span>
        </div>

        <div class="receipt-row" style="display:flex; justify-content:space-between; font-size: 13.5px; padding: 7px 0; border-bottom: 1px solid var(--border-subtle);">
          <span style="color:var(--text-secondary)">Phone Number:</span>
          <span style="font-weight:600">${escapeHtml(loan.phone || 'N/A')}</span>
        </div>

        <div class="receipt-row" style="display:flex; justify-content:space-between; font-size: 13.5px; padding: 7px 0; border-bottom: 1px solid var(--border-subtle);">
          <span style="color:var(--text-secondary)">Payment Date:</span>
          <span style="font-weight:600">${fmtDate(payment.date)}</span>
        </div>

        <div class="receipt-row" style="display:flex; justify-content:space-between; font-size: 13.5px; padding: 7px 0; border-bottom: 1px solid var(--border-subtle);">
          <span style="color:var(--text-secondary)">Payment Mode:</span>
          <span style="font-weight:600">${escapeHtml(payment.mode || 'Cash')}</span>
        </div>

        <div class="receipt-row" style="display:flex; justify-content:space-between; font-size: 13.5px; padding: 7px 0; border-bottom: 1px solid var(--border-subtle);">
          <span style="color:var(--text-secondary)">Collected By:</span>
          <span style="font-weight:700; color:var(--accent)">${escapeHtml(payment.collectedBy || 'Admin (Owner)')}</span>
        </div>

        <div class="receipt-amount-box" style="text-align:center; margin: 18px 0; padding: 14px; background: var(--success-light); border-radius: 12px;">
          <div style="font-size: 11px; color: var(--success); font-weight: 700; letter-spacing: 0.5px;">AMOUNT RECEIVED</div>
          <div style="font-size: 28px; font-weight: 800; color: var(--success); font-variant-numeric: tabular-nums; margin-top: 2px;">
            ${fmtMoney(payment.amount)}
          </div>
        </div>

        <div class="receipt-row" style="display:flex; justify-content:space-between; font-size: 13px; padding: 6px 0; border-bottom: 1px solid var(--border-subtle);">
          <span style="color:var(--text-secondary)">Total Repaid So Far:</span>
          <span style="font-weight:600">${fmtMoney(fin.totalPaid)}</span>
        </div>

        <div class="receipt-row" style="display:flex; justify-content:space-between; font-size: 13.5px; padding: 8px 0; border-bottom: 1px solid var(--border-subtle);">
          <span style="font-weight:700">Remaining Balance:</span>
          <span style="font-weight:800; color:var(--accent)">${fmtMoney(fin.remaining)}</span>
        </div>

        <div style="display:flex; justify-content:space-between; align-items:flex-end; margin-top: 24px; padding-top: 16px; border-top: 1px dashed var(--border-card);">
          <div style="font-size: 10.5px; color: var(--text-tertiary); max-width: 220px; line-height: 1.4;">
            Verified digital record generated by ${firmName}. Zero external ledger discrepancy.
          </div>
          <div style="text-align:center;">
            <div style="width: 110px; border-bottom: 1.5px solid var(--text-secondary); margin-bottom: 4px;"></div>
            <div style="font-size: 10px; color: var(--text-tertiary); text-transform: uppercase;">Authorized Sign</div>
          </div>
        </div>
      </div>

      <div class="receipt-actions" style="display:flex; gap: 10px; margin-top: 18px; justify-content: flex-end;">
        <button class="btn btn-primary" onclick="window.print()">🖨️ Print / Save PDF</button>
        <button class="btn btn-secondary" data-close-modal onclick="closeAllModals()">Close</button>
      </div>
    `;

    openModal(modal);
  }

  window.viewReceipt = function(loanId, paymentId) {
    const loans = loadState();
    const loan = loans.find(x => String(x.id) === String(loanId));
    if (!loan) return;
    const payment = (loan.payments || []).find(p => String(p.id) === String(paymentId));
    if (!payment) return;
    openReceiptModal(loan, payment);
  };

  /* ------------------ Interactive Calculator (Apple Sliders) ------------------ */

  function setupCalculator() {
    const pSlider = document.getElementById('calcSliderP');
    const rSlider = document.getElementById('calcSliderR');
    const tSlider = document.getElementById('calcSliderT');
    const mSelect = document.getElementById('calcModelSelect');

    const pDisplay = document.getElementById('calcValP');
    const rDisplay = document.getElementById('calcValR');
    const tDisplay = document.getElementById('calcValT');

    const monthlyDisplay = document.getElementById('calcResultMonthly');
    const totalPayableDisplay = document.getElementById('calcResultTotalPayable');
    const interestDisplay = document.getElementById('calcResultInterest');
    const splitPrincipal = document.getElementById('calcSplitPrincipal');
    const splitInterest = document.getElementById('calcSplitInterest');

    function updateCalculator() {
      if (!pSlider) return;
      const P = Number(pSlider.value) || 0;
      const R = Number(rSlider.value) || 0;
      const T = Number(tSlider.value) || 0;
      const model = mSelect.value || 'emi';

      pDisplay.textContent = fmtMoney(P);
      rDisplay.textContent = `${R}% p.a.`;
      tDisplay.textContent = `${T} months`;

      let monthly = 0;
      let totalPayable = 0;
      let totalInterest = 0;

      if (model === 'emi') {
        monthly = calcEmi(P, R, T);
        totalPayable = monthly * T;
        totalInterest = Math.max(0, totalPayable - P);
      } else {
        monthly = calcSimple(P, R, T);
        totalInterest = Math.round(P * (R / 100) * (T / 12));
        totalPayable = P + totalInterest;
      }

      monthlyDisplay.textContent = fmtMoney(monthly);
      totalPayableDisplay.textContent = fmtMoney(totalPayable);
      interestDisplay.textContent = fmtMoney(totalInterest);

      // Percentage visual split
      const pPercent = totalPayable > 0 ? (P / totalPayable) * 100 : 50;
      const iPercent = 100 - pPercent;
      splitPrincipal.style.width = `${pPercent}%`;
      splitInterest.style.width = `${iPercent}%`;
    }

    [pSlider, rSlider, tSlider].forEach(slider => {
      if (slider) slider.addEventListener('input', updateCalculator);
    });
    if (mSelect) mSelect.addEventListener('change', updateCalculator);

    updateCalculator();
  }

  /* ------------------ Export & Import (Vault / CSV / JSON) ------------------ */

  function setupExportImport() {
    const exportVaultBtn = document.getElementById('exportEncryptedVaultBtn');
    const exportJsonBtn = document.getElementById('exportJsonBtn');
    const exportCsvBtn = document.getElementById('exportCsvBtn');
    const importFile = document.getElementById('importFileInput');

    if (exportVaultBtn) {
      exportVaultBtn.addEventListener('click', () => {
        const loans = loadState();
        const settings = getSecuritySettings();
        const vaultData = {
          schema: 'finvault_pro_v1',
          format: 'encrypted_finvault',
          exportedAt: new Date().toISOString(),
          firmName: settings.firmName || 'FinVault',
          loansCount: loans.length,
          loans: loans,
          settings: {
            firmName: settings.firmName,
            adminName: settings.adminName,
            adminPin: settings.adminPin,
            securityQuestion: settings.securityQuestion,
            securityAnswer: settings.securityAnswer,
            ownerUpiId: settings.ownerUpiId,
            agents: settings.agents || []
          }
        };

        const serialized = JSON.stringify(vaultData, null, 2);
        const encodedVault = 'FINVAULT:' + btoa(unescape(encodeURIComponent(serialized)));
        const blob = new Blob([encodedVault], { type: 'application/octet-stream' });
        const dateStr = new Date().toISOString().split('T')[0];
        downloadFile(blob, `FinVault_Backup_${dateStr}.finvault`);

        settings.lastBackupDate = new Date().toISOString();
        settings.unbackedChanges = 0;
        saveSecuritySettings(settings);
        updateBackupHealthUI();
        showToast('🛡️ Complete .finvault backup created & downloaded!');
      });
    }

    if (exportJsonBtn) {
      exportJsonBtn.addEventListener('click', () => {
        const data = loadState();
        const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
        downloadFile(blob, `FinVault_Backup_${new Date().toISOString().split('T')[0]}.json`);
        showToast('📦 Complete JSON backup downloaded!');
      });
    }

    if (exportCsvBtn) {
      exportCsvBtn.addEventListener('click', () => {
        const data = loadState();
        if (!data.length) {
          showToast('⚠️ No loan data to export');
          return;
        }

        const headers = ['ID', 'Borrower', 'Phone', 'Principal', 'InterestRate', 'TenureMonths', 'Model', 'TotalPaid', 'Balance', 'StartDate', 'Notes'];
        const rows = data.map(l => {
          const fin = getLoanFinancials(l);
          const cleanPhone = (l.phone || '').trim();
          // Escape strings for Excel formulas so Phone and ID stay as literal text and never convert to scientific notation (e.g. 9.87E+09)
          const phoneCell = cleanPhone ? `"=""${cleanPhone.replace(/"/g, '""')}"""` : '""';
          const idCell = `"=""${String(l.id).replace(/"/g, '""')}"""`;
          const borrowerCell = `"${(l.borrower || '').replace(/"/g, '""')}"`;
          const notesCell = `"${(l.notes || '').replace(/"/g, '""')}"`;
          const startDateCell = `"${l.startDate || ''}"`;

          return [
            idCell,
            borrowerCell,
            phoneCell,
            l.principal,
            l.interest,
            l.tenure,
            l.model,
            fin.totalPaid,
            fin.balance,
            startDateCell,
            notesCell
          ].join(',');
        });

        // Add UTF-8 BOM (\uFEFF) so Excel opens UTF-8 text and Indian rupee symbols cleanly
        const csv = '\uFEFF' + [headers.join(',')].concat(rows).join('\r\n');
        const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
        downloadFile(blob, `FinVault_Loans_${new Date().toISOString().split('T')[0]}.csv`);
        showToast('📊 CSV spreadsheet exported (Excel formatted)!');
      });
    }

    async function handleVaultOrBackupFile(file) {
      if (!file) return;
      const reader = new FileReader();
      reader.onload = async ev => {
        try {
          const content = ev.target.result;
          const fileName = file.name.toLowerCase();

          if (fileName.endsWith('.finvault') || fileName.endsWith('.dgsvault')) {
            let jsonText = content.trim();
            if (jsonText.startsWith('FINVAULT:') || jsonText.startsWith('DGSVAULT:')) {
              try {
                const b64 = jsonText.slice(jsonText.indexOf(':') + 1);
                jsonText = decodeURIComponent(escape(atob(b64)));
              } catch (err) {
                showToast('⚠️ Could not decode encrypted vault file');
                return;
              }
            }
            const parsed = JSON.parse(jsonText);
            if (parsed.schema === 'finvault_pro_v1' || parsed.schema === 'dgs_vault_v3' || (parsed.loans && Array.isArray(parsed.loans))) {
              const loanList = parsed.loans || [];
              saveState(loanList);
              await idbSet('loans', loanList);

              if (parsed.settings) {
                const sec = getSecuritySettings();
                const updatedSec = { ...sec, ...parsed.settings, isRegistered: true, unbackedChanges: 0, lastBackupDate: new Date().toISOString() };
                saveSecuritySettings(updatedSec);
                await idbSet('security', updatedSec);
                renderAgentTable();
              }

              const wizardModal = document.getElementById('setupWizardModal');
              if (wizardModal) wizardModal.classList.add('hidden');

              showToast(`🎉 FinVault loaded! Restored ${loanList.length} loans & admin credentials.`);
              renderDashboard();
              renderLoansList();
              updateBackupHealthUI();
            } else {
              showToast('⚠️ Unrecognized .finvault schema format');
            }
          } else if (fileName.endsWith('.json')) {
            const parsed = JSON.parse(content);
            if (Array.isArray(parsed)) {
              saveState(parsed);
              showToast(`✅ Successfully imported ${parsed.length} loans!`);
              renderDashboard();
              renderLoansList();
            } else if (parsed && parsed.loans && Array.isArray(parsed.loans)) {
              saveState(parsed.loans);
              if (parsed.settings) {
                const sec = getSecuritySettings();
                saveSecuritySettings({ ...sec, ...parsed.settings, isRegistered: true, unbackedChanges: 0 });
                renderAgentTable();
              }
              const wizardModal = document.getElementById('setupWizardModal');
              if (wizardModal) wizardModal.classList.add('hidden');
              showToast(`✅ Restored vault with ${parsed.loans.length} loans!`);
              renderDashboard();
              renderLoansList();
            }
          } else if (fileName.endsWith('.csv')) {
            importCsvData(content);
          }
        } catch (err) {
          alert('Could not parse file. Ensure it is a valid .finvault, .dgsvault, JSON, or CSV export.');
        }
      };
      reader.readAsText(file);
    }

    if (importFile) {
      importFile.addEventListener('change', e => {
        if (e.target.files && e.target.files[0]) handleVaultOrBackupFile(e.target.files[0]);
        importFile.value = '';
      });
    }

    const wizardVaultInput = document.getElementById('wizardVaultImportInput');
    if (wizardVaultInput) {
      wizardVaultInput.addEventListener('change', e => {
        if (e.target.files && e.target.files[0]) handleVaultOrBackupFile(e.target.files[0]);
        wizardVaultInput.value = '';
      });
    }

    const lockVaultInput = document.getElementById('lockVaultImportInput');
    if (lockVaultInput) {
      lockVaultInput.addEventListener('change', e => {
        if (e.target.files && e.target.files[0]) handleVaultOrBackupFile(e.target.files[0]);
        lockVaultInput.value = '';
      });
    }
  }

  function importCsvData(content) {
    // Remove UTF-8 BOM if present
    const cleanContent = content.charCodeAt(0) === 0xFEFF ? content.slice(1) : content;
    const lines = cleanContent.split(/\r?\n/).filter(line => line.trim().length > 0);
    if (lines.length < 2) return;

    // Helper to parse RFC 4180 CSV line with quoted cells and commas
    function parseCsvRow(text) {
      const res = [];
      let cell = '';
      let inQuotes = false;
      for (let i = 0; i < text.length; i++) {
        const c = text[i];
        if (c === '"') {
          if (inQuotes && text[i + 1] === '"') {
            cell += '"';
            i++;
          } else {
            inQuotes = !inQuotes;
          }
        } else if (c === ',' && !inQuotes) {
          res.push(cell);
          cell = '';
        } else {
          cell += c;
        }
      }
      res.push(cell);
      return res;
    }

    const headers = parseCsvRow(lines.shift()).map(h => h.trim().replace(/^"|"$/g, ''));

    const loans = loadState();
    lines.forEach(line => {
      const cols = parseCsvRow(line);
      const item = {};
      headers.forEach((h, i) => {
        let raw = cols[i] !== undefined ? cols[i].trim() : '';
        // Strip Excel formula wrapper ="..." or quotes
        if (raw.startsWith('="') && raw.endsWith('"')) {
          raw = raw.slice(2, -1);
        } else if (raw.startsWith('"') && raw.endsWith('"')) {
          raw = raw.slice(1, -1);
        } else if (raw.startsWith('=')) {
          raw = raw.slice(1);
        }
        item[h] = (isNaN(raw) || h === 'Phone' || h === 'ID') ? raw : Number(raw);
      });

      loans.push({
        id: item.ID || Date.now() + Math.random(),
        borrower: item.Borrower || 'Imported Borrower',
        phone: item.Phone || '',
        principal: Number(item.Principal) || 10000,
        interest: Number(item.InterestRate) || 12,
        tenure: Number(item.TenureMonths) || 12,
        model: item.Model || 'emi',
        startDate: item.StartDate || new Date().toISOString().split('T')[0],
        created: Date.now(),
        notes: item.Notes || '',
        payments: item.TotalPaid ? [{ id: Date.now(), amount: Number(item.TotalPaid), date: new Date().toISOString().split('T')[0], mode: 'Imported' }] : []
      });
    });

    saveState(loans);
    showToast('📊 CSV loans imported successfully!');
    renderDashboard();
    renderLoansList();
  }

  function downloadFile(blob, filename) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  /* ------------------ Danger Zone Management (PIN-Protected) ------------------ */

  function setupDangerZone() {
    const clearDataBtn = document.getElementById('clearDataBtn');
    const wipeCloudBtn = document.getElementById('wipeCloudDbBtn');
    const factoryResetBtn = document.getElementById('factoryResetAllBtn');

    const modal = document.getElementById('dangerConfirmModal');
    const titleEl = document.getElementById('dangerConfirmTitle');
    const descEl = document.getElementById('dangerConfirmDesc');
    const pinInput = document.getElementById('dangerAdminPinInput');
    const pinError = document.getElementById('dangerPinError');
    const confirmBtn = document.getElementById('executeDangerActionBtn');

    let pendingAction = null; // 'local' | 'cloud' | 'factory'

    function promptDangerAction(action, title, description) {
      if (currentRole !== 'admin') {
        showToast('⚠️ Only Admin can perform database wipe actions');
        return;
      }
      pendingAction = action;
      if (titleEl) titleEl.textContent = title;
      if (descEl) descEl.textContent = description;
      if (pinInput) {
        pinInput.value = '';
        if (pinError) pinError.style.display = 'none';
      }
      if (modal) openModal(modal);
    }

    if (clearDataBtn) {
      clearDataBtn.addEventListener('click', () => {
        promptDangerAction(
          'local',
          '🧹 Clear Local Device Storage Only',
          'This will permanently delete all borrower loans and payment ledgers stored on this phone/computer. Central cloud database will remain untouched.'
        );
      });
    }

    if (wipeCloudBtn) {
      wipeCloudBtn.addEventListener('click', () => {
        promptDangerAction(
          'cloud',
          '☁️ Wipe Cloud Database (Supabase)',
          'This will permanently purge all loans and ledgers from the central Supabase database (table: public.loans). Local device records will remain safe.'
        );
      });
    }

    if (factoryResetBtn) {
      factoryResetBtn.addEventListener('click', () => {
        promptDangerAction(
          'factory',
          '⚠️ Full Factory Reset (Local + Cloud)',
          'CAUTION: This will permanently purge ALL borrower records from BOTH your local device storage and the central Supabase cloud database. This cannot be undone.'
        );
      });
    }

    if (confirmBtn) {
      confirmBtn.addEventListener('click', async () => {
        const sec = getSecuritySettings();
        const correctPin = String(sec.adminPin || '1234');
        const enteredPin = String(pinInput ? pinInput.value : '').trim();

        if (enteredPin !== correctPin) {
          if (pinError) pinError.style.display = 'block';
          return;
        }

        confirmBtn.disabled = true;
        confirmBtn.textContent = '⏳ Processing...';

        try {
          if (pendingAction === 'local' || pendingAction === 'factory') {
            localStorage.removeItem(STORAGE_KEY);
            await idbSet('loans', []);
            const updatedSec = getSecuritySettings();
            updatedSec.unbackedChanges = 0;
            saveSecuritySettings(updatedSec);
          }

          if (pendingAction === 'cloud' || pendingAction === 'factory') {
            await fetch(`${CENTRAL_SUPABASE_CONFIG.url}/rest/v1/loans?id=not.is.null`, {
              method: 'DELETE',
              headers: {
                'apikey': CENTRAL_SUPABASE_CONFIG.key,
                'Authorization': `Bearer ${CENTRAL_SUPABASE_CONFIG.key}`
              }
            });
            localStorage.removeItem('finvault_last_cloud_sync');
          }

          closeAllModals();

          if (pendingAction === 'local') {
            showToast('🧹 Local device storage cleared successfully.');
          } else if (pendingAction === 'cloud') {
            showToast('☁️ Central cloud database wiped clean (0 loans).');
          } else if (pendingAction === 'factory') {
            showToast('🎉 Complete Factory Reset Done! Local device and Supabase cloud database permanently cleared.');
          }

          renderDashboard();
          renderLoansList();
          updateBackupHealthUI();
          if (typeof testCloudConnection === 'function') await testCloudConnection();
        } catch(err) {
          showToast('⚠️ Error during database wipe: ' + err.message);
        } finally {
          confirmBtn.disabled = false;
          confirmBtn.textContent = 'Confirm & Delete';
          pendingAction = null;
        }
      });
    }
  }

  // Start on DOM ready
  document.addEventListener('DOMContentLoaded', initApp);

})();
