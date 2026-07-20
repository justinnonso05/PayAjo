import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem(this.question, this.answer);
}

const _kFaqs = [
  _FaqItem(
    'How does PayAjo work?',
    "Create or join a savings group, agree on a contribution amount and frequency, and each round every member contributes into the pool. One member receives the full payout each round, rotating until everyone has been paid.",
  ),
  _FaqItem(
    'Is my money safe?',
    "Yes. Contributions and wallet balances sit in bank-partnered virtual accounts, every member is BVN-verified before joining a group, and every payment is confirmed with your transaction PIN.",
  ),
  _FaqItem(
    'What is a Reserved Account?',
    "A dedicated virtual bank account number tied to your personal wallet. Transfer any amount to it from any bank app, and it lands in your PayAjo wallet automatically.",
  ),
  _FaqItem(
    'Can I withdraw anytime?',
    "Yes — once you've set up a payout bank, your wallet balance can be withdrawn anytime, straight to your bank account.",
  ),
  _FaqItem(
    'Do I need BVN?',
    "Yes. BVN verification is required for every member so groups stay secure and everyone in the circle is a verified real person.",
  ),
  _FaqItem(
    'How do payouts work?',
    "Each round's contributions are pooled together. The member whose turn it is — set when the group starts, either randomized or in a manual order — receives the full pool as a payout straight to their bank account.",
  ),
  _FaqItem(
    'Can I join multiple groups?',
    "Yes. You can belong to as many savings groups as you like, each with its own contribution amount, frequency, and payout schedule.",
  ),
];

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  int? _openIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text('FAQ', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: _kFaqs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = _kFaqs[index];
            final isOpen = _openIndex == index;
            return Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    onTap: () => setState(() => _openIndex = isOpen ? null : index),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.question,
                              style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ),
                          AnimatedRotation(
                            turns: isOpen ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 200),
                    crossFadeState: isOpen ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                    firstChild: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(
                        item.answer,
                        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                      ),
                    ),
                    secondChild: const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
