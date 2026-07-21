import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../routing/app_router.dart';
import '../../../groups/data/group_models.dart';
import '../../../groups/data/group_repository.dart';
import '../../../home/data/home_controller.dart';
import '../create_group_success_screen.dart';

const _kFieldDecoration = InputDecoration(
  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: Color(0xFFE0E0E0), width: 1.2),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: Color(0xFFE0E0E0), width: 1.2),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: Color(0xFF1D3108), width: 1.5),
  ),
);

/// Weekday labels for `payout_day_of_week`. The backend follows the
/// common Python/ISO convention: Monday = 0 ... Sunday = 6.
const _kWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const _kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _ordinal(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  switch (day % 10) {
    case 1:
      return '${day}st';
    case 2:
      return '${day}nd';
    case 3:
      return '${day}rd';
    default:
      return '${day}th';
  }
}

class CreateGroupSheet extends ConsumerStatefulWidget {
  const CreateGroupSheet({super.key});

  @override
  ConsumerState<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<CreateGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _memberCapController = TextEditingController();

  CycleFrequency _frequency = CycleFrequency.weekly;
  int? _payoutDayOfWeek;
  int _payoutDayOfMonth = 1;
  int _payoutMonth = 1;
  TimeOfDay? _payoutTime;
  bool _isSubmitting = false;
  String? _payoutDayError;

  @override
  void dispose() {
    _groupNameController.dispose();
    _amountController.dispose();
    _memberCapController.dispose();
    super.dispose();
  }

  Future<void> _pickPayoutTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _payoutTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _payoutTime = picked);
  }

  /// Uses a real calendar instead of a raw 1–31 stepper, so a month with
  /// fewer days (February, or any 30-day month) simply doesn't offer days
  /// that don't exist — no separate validation needed.
  Future<void> _pickPayoutDate() async {
    final now = DateTime.now();
    // For monthly frequency only the day matters (it repeats every month),
    // but the picker still needs a real date to open on — clamp defensively
    // so a stale day left over from a previous month's selection (e.g. 31)
    // never produces an invalid DateTime for a shorter reference month.
    final referenceMonth = _frequency == CycleFrequency.yearly ? _payoutMonth : now.month;
    final daysInReferenceMonth = DateTime(now.year, referenceMonth + 1, 0).day;
    final safeDay = _payoutDayOfMonth.clamp(1, daysInReferenceMonth);

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, referenceMonth, safeDay),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: _frequency == CycleFrequency.yearly ? 'Select payout date' : 'Select payout day',
    );
    if (picked == null) return;
    setState(() {
      _payoutDayOfMonth = picked.day;
      if (_frequency == CycleFrequency.yearly) _payoutMonth = picked.month;
    });
  }

  /// The backend's `payout_time` field expects "HH:MM:SSZ".
  String? _formatPayoutTime(TimeOfDay? time) {
    if (time == null) return null;
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm:00Z';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1D3108)),
    );
  }

  Future<void> _submit() async {
    setState(() => _payoutDayError = null);

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_frequency == CycleFrequency.weekly && _payoutDayOfWeek == null) {
      setState(() => _payoutDayError = 'Please choose a payout day.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final amount = double.parse(_amountController.text.trim().replaceAll(',', ''));
      final memberCapText = _memberCapController.text.trim();

      final group = await ref.read(groupRepositoryProvider).createGroup(
            GroupCreateRequest(
              name: _groupNameController.text.trim(),
              contributionAmount: amount,
              cycleFrequency: _frequency,
              // No UI for this — the backend still requires a value, so every
              // group is created with the safest default (pause until fully funded).
              shortfallPolicy: ShortfallPolicy.hold,
              payoutDayOfWeek: _frequency == CycleFrequency.weekly ? _payoutDayOfWeek : null,
              payoutDayOfMonth:
                  _frequency == CycleFrequency.monthly || _frequency == CycleFrequency.yearly ? _payoutDayOfMonth : null,
              payoutMonth: _frequency == CycleFrequency.yearly ? _payoutMonth : null,
              memberCap: memberCapText.isEmpty ? null : int.tryParse(memberCapText),
              payoutTime: _formatPayoutTime(_payoutTime),
            ),
          );

      if (!mounted) return;
      // So Home already shows the new group by the time the user gets back
      // there — no need to rely on them remembering to pull-to-refresh.
      ref.read(homeControllerProvider.notifier).refresh();
      Navigator.pop(context);
      context.goNamed(
        AppRoute.createGroupSuccess.name,
        extra: CreateGroupSuccessData(
          groupName: group.name,
          contributionAmount: '₦${formatAmount(group.contributionAmount)}',
          contributionFrequency: (group.cycleFrequency ?? _frequency).label,
          inviteCode: group.inviteCode ?? '—',
        ),
      );
    } on ApiException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Create a Group',
                    style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1D3108)),
                  ),
                  IconButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Start a saving group and define the contribution schedule.',
                style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),

              _label('Group Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _groupNameController,
                style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1D3108)),
                decoration: _kFieldDecoration.copyWith(
                  hintText: 'e.g. Monthly Traders',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Group name is required' : null,
              ),
              const SizedBox(height: 20),

              _label('Contribution Amount'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1D3108)),
                decoration: _kFieldDecoration.copyWith(
                  prefixText: '₦ ',
                  prefixStyle: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.bold, color: const Color(0xFF1D3108), fontSize: 16),
                  hintText: '10,000',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                ),
                validator: (value) {
                  final amount = double.tryParse((value ?? '').trim().replaceAll(',', ''));
                  if (amount == null || amount <= 0) return 'Enter a valid contribution amount';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              _label('Contribution Frequency'),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final freq in CycleFrequency.values) ...[
                    _ChoiceChipOption(
                      title: freq.label,
                      isSelected: _frequency == freq,
                      onTap: () => setState(() => _frequency = freq),
                    ),
                    if (freq != CycleFrequency.values.last) const SizedBox(width: 12),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              if (_frequency == CycleFrequency.weekly) ...[
                _label('Payout Day'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_kWeekdays.length, (index) {
                    return _ChoiceChipOption(
                      title: _kWeekdays[index],
                      isSelected: _payoutDayOfWeek == index,
                      onTap: () => setState(() {
                        _payoutDayOfWeek = index;
                        _payoutDayError = null;
                      }),
                      compact: true,
                    );
                  }),
                ),
                if (_payoutDayError != null) ...[
                  const SizedBox(height: 6),
                  Text(_payoutDayError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
                const SizedBox(height: 20),
              ],

              if (_frequency == CycleFrequency.monthly || _frequency == CycleFrequency.yearly) ...[
                _label(_frequency == CycleFrequency.yearly ? 'Payout Date' : 'Payout Day of Month'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickPayoutDate,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE0E0E0), width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _frequency == CycleFrequency.yearly
                              ? '${_ordinal(_payoutDayOfMonth)} of ${_kMonthNames[_payoutMonth - 1]}'
                              : '${_ordinal(_payoutDayOfMonth)} of every month',
                          style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: Color(0xFF1D3108), fontWeight: FontWeight.bold),
                        ),
                        const Icon(Icons.calendar_today_rounded, color: Color(0xFF9CA3AF), size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              _label('Payout Time (optional)'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickPayoutTime,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE0E0E0), width: 1.2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _payoutTime != null ? _payoutTime!.format(context) : 'Not set',
                        style: TextStyle(fontFamily: 'PlusJakartaSans', 
                          fontSize: 14,
                          color: _payoutTime != null ? const Color(0xFF1D3108) : const Color(0xFF9CA3AF),
                          fontWeight: _payoutTime != null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const Icon(Icons.access_time_rounded, color: Color(0xFF9CA3AF), size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _label('Maximum Members (optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _memberCapController,
                keyboardType: TextInputType.number,
                style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1D3108)),
                decoration: _kFieldDecoration.copyWith(
                  hintText: '10',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFACEC87),
                    foregroundColor: const Color(0xFF1D3108),
                    disabledBackgroundColor: const Color(0xFFACEC87),
                    disabledForegroundColor: const Color(0xFF1D3108),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF1D3108)),
                        )
                      : Text('Create Group', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1D3108)),
    );
  }
}

class _ChoiceChipOption extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final bool compact;

  const _ChoiceChipOption({
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final chip = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F6E0) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF5BA72D) : const Color(0xFFE0E0E0),
            width: isSelected ? 1.8 : 1.2,
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'PlusJakartaSans', 
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFF1D3108) : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
    return compact ? chip : Expanded(child: chip);
  }
}
