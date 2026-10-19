import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../theme/app_locale.dart';
import '../../theme/fin_theme.dart';
import '../dashboard/dashboard_screen.dart';
import 'setup_wizard_screen.dart';

class PasscodeScreen extends StatefulWidget {
  const PasscodeScreen({super.key});

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen> {
  String _enteredPin = '';
  UserRole _selectedRole = UserRole.admin;
  StaffAgent? _selectedAgent;
  SecuritySettings? _settings;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await StorageService.getSettings();
    if (!s.isRegistered) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SetupWizardScreen()),
      );
      return;
    }
    setState(() {
      _settings = s;
      _isLoading = false;
      if (s.agents.isNotEmpty) {
        _selectedAgent = s.agents.first;
      }
    });
  }

  void _onKeyPress(String key) {
    if (_enteredPin.length >= 4) return;
    setState(() {
      _enteredPin += key;
      _errorMessage = null;
    });

    if (_enteredPin.length == 4) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _onClear() {
    setState(() {
      _enteredPin = '';
      _errorMessage = null;
    });
  }

  Future<void> _verifyPin() async {
    final settings = _settings;
    if (settings == null) return;

    bool valid = false;
    StaffAgent? activeAgent = _selectedAgent;

    if (_selectedRole == UserRole.admin) {
      valid = _enteredPin == settings.adminPin;
    } else {
      if (_selectedAgent != null && _enteredPin == _selectedAgent!.pin) {
        valid = true;
      } else if (settings.agents.any((a) => a.pin == _enteredPin)) {
        activeAgent = settings.agents.firstWhere((a) => a.pin == _enteredPin);
        valid = true;
      } else if (settings.coAdminPin != null && settings.coAdminPin!.isNotEmpty && _enteredPin == settings.coAdminPin) {
        valid = true;
      } else if (_enteredPin == settings.adminPin) {
        valid = true;
      }
    }

    if (valid) {
      final finalAgent = activeAgent ?? StaffAgent(
        id: 'A-field',
        name: 'Field Agent',
        phone: '',
        pin: _enteredPin,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(
            role: _selectedRole,
            agent: _selectedRole == UserRole.agent ? finalAgent : null,
            settings: settings,
          ),
        ),
      );
    } else {
      setState(() {
        _errorMessage = "Incorrect Passcode. Try again.";
        _enteredPin = '';
      });
    }
  }

  void _showJoinWithFirmCodeDialog() {
    final firmCodeCtrl = TextEditingController(text: _settings?.vaultId ?? '');
    final nameCtrl = TextEditingController();
    final pinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.badge_outlined, color: FinTheme.primary),
            SizedBox(width: 8),
            Text("Field Agent Login", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter the 6-Digit Firm Code provided by your Master Admin to sync with the office ledger.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: firmCodeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: "6-Digit Firm Code *",
                hintText: "e.g. FV-849201",
                prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: "Your Name *",
                hintText: "e.g. Ramesh Kumar",
                prefixIcon: const Icon(Icons.person_outline, size: 18),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "4-Digit Passcode *",
                hintText: "Your 4-digit PIN",
                prefixIcon: const Icon(Icons.lock_outline, size: 18),
                counterText: "",
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = firmCodeCtrl.text.trim().toUpperCase();
              final name = nameCtrl.text.trim();
              final pin = pinCtrl.text.trim();

              if (code.isEmpty || name.isEmpty || pin.length != 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please fill all fields with a 4-digit PIN")),
                );
                return;
              }

              final newAgent = StaffAgent(
                id: "A-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}",
                name: name,
                phone: '',
                pin: pin,
              );

              final current = _settings ?? await StorageService.getSettings();
              final updated = current.copyWith(
                vaultId: code,
                isRegistered: true,
                agents: [...current.agents, newAgent],
              );
              await StorageService.saveSettings(updated);

              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => DashboardScreen(
                    role: UserRole.agent,
                    agent: newAgent,
                    settings: updated,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: FinTheme.primary),
            child: const Text("Join & Login"),
          ),
        ],
      ),
    );
  }

  void _showRecoveryDialog() {
    if (_settings == null) return;
    final answerCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Security Recovery", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_settings!.securityQuestion, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: answerCtrl,
                decoration: const InputDecoration(
                  hintText: "Your Answer",
                  prefixIcon: Icon(Icons.help_outline),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final ans = answerCtrl.text.trim().toLowerCase();
                if (ans == _settings!.securityAnswer.trim().toLowerCase()) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Passcode Verified! Master PIN: ${_settings!.adminPin}"),
                      backgroundColor: FinTheme.success,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Incorrect security answer"),
                      backgroundColor: FinTheme.danger,
                    ),
                  );
                }
              },
              child: const Text("Verify"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? FinTheme.bgDark : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // App Icon & Brand
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: FinTheme.primary.withOpacity(0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _settings?.firmName ?? 'FinVault',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Smart Loan & Repayment Ledger",
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // Role Segment (Always shows BOTH Master Admin and Field Agent!)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? FinTheme.cardDark : const Color(0xFFF0F2F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedRole = UserRole.admin;
                          _enteredPin = '';
                          _errorMessage = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedRole == UserRole.admin
                                ? (isDark ? const Color(0xFF232D3F) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _selectedRole == UserRole.admin
                                ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.admin_panel_settings,
                                size: 16,
                                color: _selectedRole == UserRole.admin ? FinTheme.primary : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Master Admin",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedRole == UserRole.admin
                                      ? (isDark ? Colors.white : FinTheme.textLightPrimary)
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedRole = UserRole.agent;
                          _enteredPin = '';
                          _errorMessage = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedRole == UserRole.agent
                                ? (isDark ? const Color(0xFF232D3F) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _selectedRole == UserRole.agent
                                ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.badge,
                                size: 16,
                                color: _selectedRole == UserRole.agent ? FinTheme.success : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Field Agent",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedRole == UserRole.agent
                                      ? (isDark ? Colors.white : FinTheme.textLightPrimary)
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Agent Selection Chip or Link Option
              if (_selectedRole == UserRole.agent) ...[
                const SizedBox(height: 10),
                if (_settings?.agents.isNotEmpty == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2838) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<StaffAgent>(
                      value: _selectedAgent ?? _settings!.agents.first,
                      underline: const SizedBox(),
                      isDense: true,
                      items: _settings!.agents.map((a) {
                        return DropdownMenuItem(
                          value: a,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person, size: 16, color: FinTheme.primary),
                              const SizedBox(width: 8),
                              Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedAgent = val;
                            _enteredPin = '';
                            _errorMessage = null;
                          });
                        }
                      },
                    ),
                  )
                else
                  InkWell(
                    onTap: _showJoinWithFirmCodeDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: FinTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: FinTheme.primary.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link, size: 14, color: FinTheme.primary),
                          SizedBox(width: 6),
                          Text(
                            "Enter Firm Code & Connect",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: FinTheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 20),

              // PIN Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: isFilled ? 16 : 14,
                    height: isFilled ? 16 : 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled
                          ? FinTheme.primary
                          : (isDark ? Colors.white24 : const Color(0xFFD1D1D6)),
                      boxShadow: isFilled
                          ? [
                              BoxShadow(
                                color: FinTheme.primary.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                  );
                }),
              ),

              const SizedBox(height: 12),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: FinTheme.danger, fontSize: 13, fontWeight: FontWeight.w600),
                )
              else
                const SizedBox(height: 18),

              const Spacer(),

              // Keypad
              Column(
                children: [
                  _buildKeypadRow(['1', '2', '3']),
                  const SizedBox(height: 12),
                  _buildKeypadRow(['4', '5', '6']),
                  const SizedBox(height: 12),
                  _buildKeypadRow(['7', '8', '9']),
                  const SizedBox(height: 12),
                  _buildBottomRow(),
                ],
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: _showRecoveryDialog,
                child: const Text(
                  "Forgot Passcode?",
                  style: TextStyle(fontSize: 13, color: FinTheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) => _buildKey(k)).toList(),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionKey('C', _onClear, icon: Icons.clear),
        _buildKey('0'),
        _buildActionKey('backspace', _onBackspace, icon: Icons.backspace_outlined),
      ],
    );
  }

  Widget _buildKey(String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _onKeyPress(value),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? FinTheme.cardDark : const Color(0xFFF0F2F6),
        ),
        alignment: Alignment.center,
        child: Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey(String label, VoidCallback onTap, {required IconData icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? FinTheme.cardDark : const Color(0xFFF0F2F6),
        ),
        alignment: Alignment.center,
        child: label == 'C'
            ? Text(
                'C',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              )
            : Icon(icon, size: 22, color: isDark ? Colors.white60 : Colors.black54),
      ),
    );
  }
}
