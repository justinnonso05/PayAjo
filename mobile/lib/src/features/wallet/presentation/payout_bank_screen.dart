import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routing/app_router.dart';
import '../data/payout_bank_models.dart';
import '../data/wallet_repository.dart';

class PayoutBankScreen extends ConsumerStatefulWidget {
  const PayoutBankScreen({super.key});

  @override
  ConsumerState<PayoutBankScreen> createState() => _PayoutBankScreenState();
}

class _PayoutBankScreenState extends ConsumerState<PayoutBankScreen> {
  final _accountNumberController = TextEditingController();

  List<Bank> _banks = [];
  bool _isLoadingBanks = true;
  Bank? _selectedBank;
  BankValidationResult? _validated;
  bool _isValidating = false;
  bool _isContinuing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBanks();
    _accountNumberController.addListener(() {
      if (_validated != null) setState(() => _validated = null);
    });
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadBanks() async {
    try {
      final banks = await ref.read(walletRepositoryProvider).getBanks();
      if (!mounted) return;
      setState(() {
        _banks = banks;
        _isLoadingBanks = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingBanks = false;
        _error = e.message;
      });
    }
  }

  Future<void> _pickBank() async {
    final bank = await showModalBottomSheet<Bank>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => _BankPickerSheet(banks: _banks),
    );
    if (bank != null) {
      setState(() {
        _selectedBank = bank;
        _validated = null;
      });
    }
  }

  Future<void> _validate() async {
    final bank = _selectedBank;
    final accountNumber = _accountNumberController.text.trim();
    if (bank == null || accountNumber.length != 10) return;

    setState(() {
      _isValidating = true;
      _error = null;
    });
    try {
      final result = await ref.read(walletRepositoryProvider).validateBankAccount(
            accountNumber: accountNumber,
            bankCode: bank.code,
          );
      if (!mounted) return;
      setState(() {
        _validated = result;
        _isValidating = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isValidating = false;
        _error = e.message;
      });
    }
  }

  Future<void> _continue() async {
    final bank = _selectedBank;
    final validated = _validated;
    if (bank == null || validated == null) return;

    setState(() {
      _isContinuing = true;
      _error = null;
    });
    try {
      await ref.read(walletRepositoryProvider).requestPayoutBankOtp();
      if (!mounted) return;
      context.pushNamed(
        AppRoute.payoutBankOtp.name,
        extra: {
          'bankCode': bank.code,
          'accountNumber': validated.accountNumber,
          'accountName': validated.accountName,
          'bankName': bank.name,
        },
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isContinuing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canValidate = _selectedBank != null && _accountNumberController.text.trim().length == 10;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text('Payout Bank', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Where should withdrawals go?',
                style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                "Set this once. Every withdrawal after this goes straight to this account, no need to re-enter it.",
                style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 28),

              Text('Bank', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _isLoadingBanks ? null : _pickBank,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border, width: 1.2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isLoadingBanks ? 'Loading banks…' : (_selectedBank?.name ?? 'Select a bank'),
                        style: TextStyle(fontFamily: 'PlusJakartaSans', 
                          fontSize: 14,
                          color: _selectedBank != null ? AppColors.textPrimary : AppColors.hint,
                          fontWeight: _selectedBank != null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.hint),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text('Account Number', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '0123456789',
                  hintStyle: const TextStyle(color: AppColors.hint, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border, width: 1.2)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border, width: 1.2)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.darkGreen, width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),

              if (_validated != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.paleGreen, borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.accentGreen, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _validated!.accountName,
                          style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: (canValidate && !_isValidating) ? _validate : null,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                    ),
                    child: _isValidating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary))
                        : Text('Verify Account', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ),
                ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ],

              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_validated != null && !_isContinuing) ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    foregroundColor: AppColors.darkGreen,
                    disabledBackgroundColor: AppColors.divider,
                    disabledForegroundColor: AppColors.textMuted,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: _isContinuing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.darkGreen))
                      : Text('Continue', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BankPickerSheet extends StatefulWidget {
  final List<Bank> banks;

  const _BankPickerSheet({required this.banks});

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final _searchController = TextEditingController();
  late List<Bank> _filtered = widget.banks;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      _filtered = widget.banks.where((b) => b.name.toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Bank', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: _onSearch,
              style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search banks…',
                hintStyle: const TextStyle(color: AppColors.hint, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.hint),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border, width: 1.2)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border, width: 1.2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.darkGreen, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: _filtered.length,
                separatorBuilder: (context, index) => Divider(color: Colors.grey[100]),
                itemBuilder: (context, index) {
                  final bank = _filtered[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(bank.name, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: AppColors.textPrimary)),
                    onTap: () => Navigator.pop(context, bank),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
