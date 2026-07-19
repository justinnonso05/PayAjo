import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../data/receipt_pdf.dart';
import '../../data/wallet_models.dart';
import '../../data/wallet_repository.dart';

/// Tapping a transaction opens this — fetches `GET
/// /users/me/wallet/transactions/{id}` and renders it as a receipt.
class TransactionReceiptSheet extends ConsumerStatefulWidget {
  final String transactionId;

  const TransactionReceiptSheet({super.key, required this.transactionId});

  static Future<void> show(BuildContext context, String transactionId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => TransactionReceiptSheet(transactionId: transactionId),
    );
  }

  @override
  ConsumerState<TransactionReceiptSheet> createState() => _TransactionReceiptSheetState();
}

class _TransactionReceiptSheetState extends ConsumerState<TransactionReceiptSheet> {
  TransactionReceipt? _receipt;
  bool _isLoading = true;
  String? _error;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final receipt = await ref.read(walletRepositoryProvider).getTransactionReceipt(widget.transactionId);
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load this receipt.';
        _isLoading = false;
      });
    }
  }

  void _copyReference(String reference) {
    Clipboard.setData(ClipboardData(text: reference));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reference copied', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen),
    );
  }

  Future<void> _downloadPdf() async {
    if (_receipt == null || _isExporting) return;
    setState(() => _isExporting = true);
    try {
      await shareReceiptPdf(_receipt!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate the PDF: $e', style: const TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
      child: _isLoading
          ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: AppColors.accentGreen)))
          : _error != null
              ? SizedBox(
                  height: 160,
                  child: Center(
                    child: Text(_error!, style: TextStyle(fontFamily: 'PlusJakartaSans', color: AppColors.textSecondary), textAlign: TextAlign.center),
                  ),
                )
              : _buildReceipt(_receipt!),
    );
  }

  Widget _buildReceipt(TransactionReceipt receipt) {
    final isCredit = _isCreditType(receipt.type);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Transaction Receipt', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: Column(
            children: [
              Text(
                '${isCredit ? '+' : '-'}₦${formatAmount(receipt.amount.abs())}',
                style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 30, fontWeight: FontWeight.bold, color: isCredit ? AppColors.accentGreen : AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              StatusPill(label: receipt.status, tone: _toneForStatus(receipt.status)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Column(
            children: [
              _row('Type', _friendlyType(receipt.type)),
              _divider(),
              _row('Date', formatShortDate(receipt.date)),
              _divider(),
              _row('Time', formatTime(receipt.date)),
              if (receipt.senderName != null) ...[_divider(), _row('From', receipt.senderName!)],
              if (receipt.recipientName != null) ...[_divider(), _row('To', receipt.recipientName!)],
              if (receipt.narration != null && receipt.narration!.isNotEmpty) ...[_divider(), _row('Narration', receipt.narration!)],
              if (receipt.reference != null && receipt.reference!.isNotEmpty) ...[
                _divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Text('Reference', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Flexible(
                        child: GestureDetector(
                          onTap: () => _copyReference(receipt.reference!),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  receipt.reference!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.copy_rounded, size: 14, color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _isExporting ? null : _downloadPdf,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            icon: _isExporting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary))
                : const Icon(Icons.download_rounded, size: 18, color: AppColors.textPrimary),
            label: Text(
              _isExporting ? 'Preparing…' : 'Download as PDF',
              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: Colors.grey[100]);

  String _friendlyType(String type) {
    final words = type.replaceAll('_', ' ').split(' ');
    return words.map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');
  }

  bool _isCreditType(String type) {
    final t = type.toLowerCase().replaceAll('_', '').replaceAll('-', '');
    const creditKeywords = ['deposit', 'topup', 'payout', 'refund', 'credit', 'received', 'reversal'];
    const debitKeywords = ['withdraw', 'contribution', 'debit', 'payment'];
    if (debitKeywords.any(t.contains)) return false;
    return creditKeywords.any(t.contains);
  }

  PillTone _toneForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'successful':
      case 'completed':
        return PillTone.success;
      case 'pending':
      case 'processing':
        return PillTone.warning;
      case 'failed':
      case 'reversed':
        return PillTone.danger;
      default:
        return PillTone.neutral;
    }
  }
}
