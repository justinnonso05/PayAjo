import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/pin_entry_sheet.dart';
import '../../data/wallet_models.dart';
import '../../data/wallet_repository.dart';

/// Send money to another AjoPay user by their reserved account number.
/// Pops with `true` on success, or null if dismissed.
class TransferSheet extends ConsumerStatefulWidget {
  final double balance;

  const TransferSheet({super.key, required this.balance});

  static Future<bool?> show(BuildContext context, {required double balance}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => TransferSheet(balance: balance),
    );
  }

  @override
  ConsumerState<TransferSheet> createState() => _TransferSheetState();
}

enum _LookupStatus { idle, searching, found, notFound }

class _TransferSheetState extends ConsumerState<TransferSheet> {
  final _accountController = TextEditingController();
  final _amountController = TextEditingController();
  final _narrationController = TextEditingController();

  Timer? _debounce;
  int _requestId = 0;
  _LookupStatus _status = _LookupStatus.idle;
  UserByAccount? _recipient;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _accountController.dispose();
    _amountController.dispose();
    _narrationController.dispose();
    super.dispose();
  }

  void _onAccountChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _recipient = null;
      _error = null;
    });

    final accountNumber = value.trim();
    if (accountNumber.length != 10) {
      setState(() => _status = _LookupStatus.idle);
      return;
    }

    setState(() => _status = _LookupStatus.searching);
    _debounce = Timer(const Duration(milliseconds: 400), () => _lookup(accountNumber));
  }

  Future<void> _lookup(String accountNumber) async {
    final thisRequest = ++_requestId;
    try {
      final recipient = await ref.read(walletRepositoryProvider).lookupByAccount(accountNumber);
      if (!mounted || thisRequest != _requestId) return;
      setState(() {
        _recipient = recipient;
        _status = _LookupStatus.found;
      });
    } catch (_) {
      if (!mounted || thisRequest != _requestId) return;
      setState(() => _status = _LookupStatus.notFound);
    }
  }

  Future<void> _continue() async {
    final recipient = _recipient;
    final amount = double.tryParse(_amountController.text.trim());
    if (recipient == null || amount == null || amount <= 0) return;

    if (amount > widget.balance) {
      setState(() => _error = 'That\'s more than your wallet balance.');
      return;
    }

    final pin = await PinEntrySheet.show(
      context,
      title: 'Confirm Transfer',
      subtitle: 'Enter your PIN to send ₦${formatAmount(amount)} to ${recipient.fullName.isNotEmpty ? recipient.fullName : '@${recipient.username}'}.',
    );
    if (pin == null || !mounted) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(walletRepositoryProvider).transfer(
            recipientAccountNumber: recipient.personalReservedAccountNumber,
            amount: amount,
            pin: pin,
            narration: _narrationController.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amountController.text.trim());
    final canContinue = _recipient != null && amount != null && amount > 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Transfer', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Send money to another AjoPay user instantly.',
              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Text('Recipient Account Number', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextField(
              controller: _accountController,
              keyboardType: TextInputType.number,
              maxLength: 10,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _onAccountChanged,
              style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              decoration: InputDecoration(
                counterText: '',
                hintText: '0123456789',
                hintStyle: const TextStyle(color: AppColors.hint, fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                suffixIcon: _status == _LookupStatus.searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentGreen)),
                      )
                    : _status == _LookupStatus.found
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.accentGreen)
                        : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border, width: 1.2)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border, width: 1.2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.darkGreen, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            if (_status == _LookupStatus.notFound)
              Text(
                'No AjoPay account found with that number.',
                style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12.5, color: AppColors.danger, fontWeight: FontWeight.w600),
              ),
            if (_status == _LookupStatus.found && _recipient != null)
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
                        _recipient!.fullName.isNotEmpty ? _recipient!.fullName : '@${_recipient!.username}',
                        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            if (_status == _LookupStatus.found) ...[
              const SizedBox(height: 20),
              Text(
                'Available balance: ₦${formatAmount(widget.balance)}',
                style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  prefixText: '₦ ',
                  hintText: '0.00',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.darkGreen, width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _narrationController,
                style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'What\'s it for? (optional)',
                  hintStyle: const TextStyle(color: AppColors.hint, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.darkGreen, width: 1.5)),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (canContinue && !_isSubmitting) ? _continue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: AppColors.darkGreen,
                  disabledBackgroundColor: AppColors.divider,
                  disabledForegroundColor: AppColors.textMuted,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.darkGreen))
                    : Text('Send Money', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
