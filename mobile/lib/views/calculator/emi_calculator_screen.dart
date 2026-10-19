import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/loan.dart';
import '../../theme/app_locale.dart';
import '../../theme/fin_theme.dart';
import '../loans/add_edit_loan_screen.dart';

class EmiCalculatorScreen extends StatefulWidget {
  const EmiCalculatorScreen({super.key});

  @override
  State<EmiCalculatorScreen> createState() => _EmiCalculatorScreenState();
}

class _EmiCalculatorScreenState extends State<EmiCalculatorScreen> {
  double _principal = 100000;
  double _interestRate = 2.0;
  int _tenure = 12;
  String _model = 'rupee'; // 'rupee', 'emi', or 'simple'

  late TextEditingController _principalCtrl;
  late TextEditingController _rateCtrl;
  late TextEditingController _tenureCtrl;

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  String _t(String key) => AppLocale.tr(key);

  @override
  void initState() {
    super.initState();
    _principalCtrl = TextEditingController(text: _principal.toStringAsFixed(0));
    _rateCtrl = TextEditingController(text: _interestRate.toStringAsFixed(1));
    _tenureCtrl = TextEditingController(text: _tenure.toString());
  }

  @override
  void dispose() {
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _tenureCtrl.dispose();
    super.dispose();
  }

  double get _monthlyInstallment {
    if (_model == 'rupee') {
      return Loan.calcRupeeMonthlyInterest(_principal, _interestRate);
    } else if (_model == 'emi') {
      return Loan.calcEmi(_principal, _interestRate, _tenure);
    } else {
      return Loan.calcSimple(_principal, _interestRate, _tenure);
    }
  }

  double get _totalPayable {
    if (_model == 'rupee') {
      final monthlyInterest = Loan.calcRupeeMonthlyInterest(_principal, _interestRate);
      return (_principal + (monthlyInterest * _tenure)).roundToDouble();
    } else if (_model == 'emi') {
      return (_monthlyInstallment * _tenure).roundToDouble();
    } else {
      final totalInterest = _principal * (_interestRate / 100) * (_tenure / 12);
      return (_principal + totalInterest).roundToDouble();
    }
  }

  double get _totalInterest => (_totalPayable - _principal).clamp(0.0, double.infinity);

  double get _principalRatio => _totalPayable > 0 ? (_principal / _totalPayable).clamp(0.0, 1.0) : 1.0;
  double get _interestRatio => _totalPayable > 0 ? (_totalInterest / _totalPayable).clamp(0.0, 1.0) : 0.0;

  List<AmortizationRow> get _amortizationRows {
    final tempLoan = Loan(
      id: 'temp',
      borrower: 'Preview',
      phone: '',
      principal: _principal,
      interest: _interestRate,
      tenure: _tenure,
      model: _model,
      startDate: DateTime.now().toIso8601String().split('T')[0],
      created: DateTime.now().millisecondsSinceEpoch,
      payments: [],
    );
    return tempLoan.amortizationSchedule;
  }

  Widget _buildCalcMethodTile({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _model == id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _model = id;
          if (id == 'rupee' && _interestRate > 10.0) {
            _interestRate = 2.0;
            _rateCtrl.text = "2.0";
          } else if (id != 'rupee' && _interestRate <= 5.0) {
            _interestRate = 12.0;
            _rateCtrl.text = "12.0";
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? FinTheme.primary.withOpacity(0.12)
              : (isDark ? const Color(0xFF1E2838) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? FinTheme.primary : (isDark ? FinTheme.borderDark : FinTheme.borderLight),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? FinTheme.primary : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? FinTheme.primary : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('emi_calculator')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Big Highlight Result Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0071E3), Color(0xFF0056B3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(FinTheme.radiusMedium),
                boxShadow: [
                  BoxShadow(
                    color: FinTheme.primary.withOpacity(0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                children: [
                  Text(
                    (_model == 'rupee' ? _t('monthly_interest') : _t('monthly_emi')).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currency.format(_monthlyInstallment),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _model == 'rupee' ? _t('rupee_rate_sub') : "Payable monthly",
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(_t('total_payable'), style: const TextStyle(fontSize: 11, color: Colors.white70)),
                          const SizedBox(height: 3),
                          Text(
                            _currency.format(_totalPayable),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 28, color: Colors.white24),
                      Column(
                        children: [
                          Text(_t('total_interest'), style: const TextStyle(fontSize: 11, color: Colors.white70)),
                          const SizedBox(height: 3),
                          Text(
                            _currency.format(_totalInterest),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFFD60A)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Visual Split Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          children: [
                            Expanded(
                              flex: (_principalRatio * 100).round(),
                              child: Container(height: 8, color: Colors.white),
                            ),
                            Expanded(
                              flex: (_interestRatio * 100).round(),
                              child: Container(height: 8, color: const Color(0xFFFFD60A)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Text("${_t('loan_principal')} (${(_principalRatio * 100).toStringAsFixed(0)}%)", style: const TextStyle(fontSize: 10, color: Colors.white70)),
                            ],
                          ),
                          Row(
                            children: [
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFFD60A), shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Text("${_t('total_interest')} (${(_interestRatio * 100).toStringAsFixed(0)}%)", style: const TextStyle(fontSize: 10, color: Colors.white70)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Calculator Controls Container
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? FinTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(FinTheme.radiusMedium),
                border: Border.all(color: isDark ? FinTheme.borderDark : FinTheme.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Modern 3-Card Calculation Method Selector
                  Text(_t('calc_method').toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.8)),
                  const SizedBox(height: 10),
                  _buildCalcMethodTile(
                    id: 'rupee',
                    title: _t('rupee_rate'),
                    subtitle: _t('rupee_rate_sub'),
                    icon: Icons.currency_rupee,
                    isDark: isDark,
                  ),
                  _buildCalcMethodTile(
                    id: 'emi',
                    title: _t('reducing_emi'),
                    subtitle: _t('reducing_emi_sub'),
                    icon: Icons.trending_down,
                    isDark: isDark,
                  ),
                  _buildCalcMethodTile(
                    id: 'simple',
                    title: _t('flat_simple'),
                    subtitle: _t('flat_simple_sub'),
                    icon: Icons.horizontal_rule,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 18),

                  // 1. Principal Amount Control
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_t('loan_principal'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                        _currency.format(_principal),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: FinTheme.primary),
                      ),
                    ],
                  ),
                  Slider(
                    value: _principal,
                    min: 10000,
                    max: 2000000,
                    divisions: 398,
                    activeColor: FinTheme.primary,
                    onChanged: (val) {
                      setState(() {
                        _principal = val;
                        _principalCtrl.text = val.toStringAsFixed(0);
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("₹10,000", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text("₹5,00,000", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text("₹20,00,000", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 2. Interest Rate Control (Dynamic for Rupee vs % p.a.)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _model == 'rupee' ? _t('vaddi_rate_label') : _t('interest_rate'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        _model == 'rupee'
                            ? "₹${_interestRate.toStringAsFixed(1)} vaddi / mo"
                            : "${_interestRate.toStringAsFixed(1)}% p.a.",
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: FinTheme.primary),
                      ),
                    ],
                  ),
                  Slider(
                    value: _model == 'rupee' ? _interestRate.clamp(0.5, 10.0) : _interestRate.clamp(1.0, 36.0),
                    min: _model == 'rupee' ? 0.5 : 1.0,
                    max: _model == 'rupee' ? 10.0 : 36.0,
                    divisions: _model == 'rupee' ? 19 : 70,
                    activeColor: FinTheme.primary,
                    onChanged: (val) {
                      setState(() {
                        _interestRate = val;
                        _rateCtrl.text = val.toStringAsFixed(1);
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _model == 'rupee'
                        ? const [
                            Text("₹0.50", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            Text("₹2.00 (₹2 vaddi)", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            Text("₹10.00", style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ]
                        : const [
                            Text("1%", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            Text("18%", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            Text("36%", style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                  ),

                  const SizedBox(height: 16),

                  // 3. Tenure Duration Control
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${_t('tenure_months')}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                        "$_tenure Months",
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: FinTheme.primary),
                      ),
                    ],
                  ),
                  Slider(
                    value: _tenure.toDouble(),
                    min: 1.0,
                    max: 60.0,
                    divisions: 59,
                    activeColor: FinTheme.primary,
                    onChanged: (val) {
                      setState(() {
                        _tenure = val.round();
                        _tenureCtrl.text = _tenure.toString();
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("1 Mo", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text("12 Mo", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text("60 Mo", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Quick Shortcut: Create Loan with these parameters
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditLoanScreen(
                        loanToEdit: Loan(
                          id: '',
                          borrower: '',
                          phone: '',
                          principal: _principal,
                          interest: _interestRate,
                          tenure: _tenure,
                          model: _model,
                          startDate: DateTime.now().toIso8601String().split('T')[0],
                          created: DateTime.now().millisecondsSinceEpoch,
                          payments: [],
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text(_t('apply_to_new_loan'), style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FinTheme.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Repayment Schedule Table Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${_t('amortization_schedule')} ($_tenure Months)",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Schedule Table
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _amortizationRows.length,
              itemBuilder: (context, index) {
                final row = _amortizationRows[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? FinTheme.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? FinTheme.borderDark : FinTheme.borderLight),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: FinTheme.primary.withOpacity(0.12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "${row.month}",
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FinTheme.primary),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(row.dueDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text(
                                "Prin: ${_currency.format(row.principal)} • Int: ${_currency.format(row.interest)}",
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_currency.format(row.emi), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text("Bal: ${_currency.format(row.balance)}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
