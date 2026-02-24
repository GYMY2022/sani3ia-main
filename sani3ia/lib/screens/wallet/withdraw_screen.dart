import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String selectedWallet = '';
  double currentBalance = 1000.0; // Example balance

  // Quick amount options
  final List<double> quickAmounts = [50, 100, 200, 500, 1000];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    _accountNumberController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildModernAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Balance Card
                  _buildBalanceCard(),
                  const SizedBox(height: 24),

                  // Withdrawal Method Selection
                  _buildWithdrawalMethods(),
                  const SizedBox(height: 24),

                  // Dynamic Input Fields based on selection
                  if (selectedWallet.isNotEmpty) ...[
                    if (selectedWallet != 'bank') ...[
                      _buildPhoneNumberInput(),
                      const SizedBox(height: 24),
                    ] else ...[
                      _buildBankAccountInput(),
                      const SizedBox(height: 24),
                    ],

                    // Amount Input
                    _buildAmountInput(),
                    const SizedBox(height: 20),

                    // Quick Amount Options
                    _buildQuickAmountOptions(),
                    const SizedBox(height: 24),

                    // Transaction Info
                    _buildTransactionInfo(),
                    const SizedBox(height: 30),

                    // Withdraw Button
                    _buildWithdrawButton(),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back,
            color: Color(0xFF64748B),
            size: 20,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'سحب الأموال',
        style: TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 70, 6, 198),
            Color.fromARGB(255, 108, 42, 213),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 156, 239, 68).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الرصيد المتاح للسحب',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${currentBalance.toStringAsFixed(2)} ج.م',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'اختر طريقة السحب',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),

        // Mobile Wallets Row
        Row(
          children: [
            Expanded(
              child: _buildWalletOption(
                id: 'vodafone',
                name: 'فودافون كاش',
                icon: Icons.phone_android,
                color: const Color(0xFFE60000),
                isSelected: selectedWallet == 'vodafone',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildWalletOption(
                id: 'etisalat',
                name: 'اتصالات كاش',
                icon: Icons.phone_android,
                color: const Color(0xFF00A651),
                isSelected: selectedWallet == 'etisalat',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildWalletOption(
                id: 'orange',
                name: 'اورانج كاش',
                icon: Icons.phone_android,
                color: const Color(0xFFFF7900),
                isSelected: selectedWallet == 'orange',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildWalletOption(
                id: 'bank',
                name: 'حساب بنكي',
                icon: Icons.account_balance,
                color: const Color(0xFF3B82F6),
                isSelected: selectedWallet == 'bank',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWalletOption({
    required String id,
    required String name,
    required IconData icon,
    required Color color,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedWallet = id;
          _phoneController.clear();
          _accountNumberController.clear();
          _amountController.clear();
        });
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withOpacity(0.2)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? color : const Color(0xFF64748B),
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneNumberInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'رقم المحفظة الإلكترونية',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            decoration: InputDecoration(
              hintText: '01xxxxxxxxx',
              prefixIcon: const Icon(Icons.phone, color: Color(0xFF64748B)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال رقم المحفظة';
              }
              if (value.length != 11) {
                return 'رقم المحفظة يجب أن يكون 11 رقم';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBankAccountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'رقم الحساب البنكي',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: _accountNumberController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: 'أدخل رقم الحساب البنكي',
              prefixIcon: const Icon(
                Icons.account_balance,
                color: Color(0xFF64748B),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال رقم الحساب البنكي';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'سيتم تحويل الأموال خلال 1-3 أيام عمل',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'المبلغ المطلوب سحبه',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              hintText: '0.00',
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ج.م',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال المبلغ';
              }
              final amount = double.tryParse(value);
              if (amount == null || amount <= 0) {
                return 'يرجى إدخال مبلغ صحيح';
              }
              if (amount > currentBalance) {
                return 'المبلغ أكبر من الرصيد المتاح';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {}); // Refresh UI for validation
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAmountOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'مبالغ سريعة',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: quickAmounts.map((amount) {
            return GestureDetector(
              onTap: () {
                if (amount <= currentBalance) {
                  _amountController.text = amount.toString();
                  HapticFeedback.lightImpact();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: amount <= currentBalance
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: amount <= currentBalance
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  '${amount.toInt()} ج.م',
                  style: TextStyle(
                    color: amount <= currentBalance
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTransactionInfo() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final fee = selectedWallet == 'bank'
        ? amount * 0.02
        : amount * 0.01; // 2% for bank, 1% for mobile wallets
    final total = amount - fee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تفاصيل العملية',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('المبلغ المطلوب', '${amount.toStringAsFixed(2)} ج.م'),
          _buildInfoRow('رسوم الخدمة', '${fee.toStringAsFixed(2)} ج.م'),
          const Divider(),
          _buildInfoRow(
            'المبلغ المستلم',
            '${total.toStringAsFixed(2)} ج.م',
            isTotal: true,
          ),
          const SizedBox(height: 8),
          Text(
            selectedWallet == 'bank'
                ? 'سيتم التحويل خلال 1-3 أيام عمل'
                : 'سيتم التحويل فوراً',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal
                  ? const Color(0xFF1E293B)
                  : const Color(0xFF64748B),
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isTotal
                  ? const Color(0xFF1E293B)
                  : const Color(0xFF64748B),
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawButton() {
    final hasAmount = _amountController.text.isNotEmpty;
    final hasPhone = selectedWallet != 'bank'
        ? _phoneController.text.isNotEmpty
        : _accountNumberController.text.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: hasAmount && hasPhone
            ? const LinearGradient(
                colors: [
                  Color.fromARGB(255, 68, 239, 94),
                  Color.fromARGB(255, 38, 220, 78),
                ],
              )
            : null,
        color: hasAmount && hasPhone ? null : const Color(0xFFE2E8F0),
        boxShadow: hasAmount && hasPhone
            ? [
                BoxShadow(
                  color: const Color(0xFFEF4444).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: hasAmount && hasPhone ? _processWithdrawal : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'تأكيد طلب السحب',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _processWithdrawal() {
    if (_formKey.currentState?.validate() ?? false) {
      HapticFeedback.mediumImpact();

      // Show confirmation dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('تأكيد العملية'),
          content: Text(
            'هل أنت متأكد من طلب سحب ${_amountController.text} ج.م ${_getWalletName()}؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم إرسال طلب السحب بنجاح'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('تأكيد'),
            ),
          ],
        ),
      );
    }
  }

  String _getWalletName() {
    switch (selectedWallet) {
      case 'vodafone':
        return 'إلى فودافون كاش';
      case 'etisalat':
        return 'إلى اتصالات كاش';
      case 'orange':
        return 'إلى اورانج كاش';
      case 'bank':
        return 'إلى الحساب البنكي';
      default:
        return '';
    }
  }
}
