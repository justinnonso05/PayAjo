import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../data/notification_model.dart';
import '../data/notifications_repository.dart';

IconData _iconForType(String type) {
  final t = type.toLowerCase();
  if (t.contains('payout')) return Icons.celebration_rounded;
  if (t.contains('contribution') || t.contains('payment')) return Icons.check_circle_rounded;
  if (t.contains('withdraw')) return Icons.arrow_upward_rounded;
  if (t.contains('member') || t.contains('join')) return Icons.person_add_rounded;
  if (t.contains('announcement') || t.contains('admin')) return Icons.campaign_rounded;
  if (t.contains('reminder')) return Icons.alarm_rounded;
  return Icons.notifications_rounded;
}

class NotificationsTab extends ConsumerWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notifications',
                  style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                if (state.items.any((n) => !n.isRead))
                  TextButton(
                    onPressed: controller.markAllRead,
                    child: Text(
                      'Mark all read',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.accentGreen),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accentGreen,
              onRefresh: controller.refresh,
              child: _buildBody(context, state, controller),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, NotificationsState state, NotificationsController controller) {
    if (state.isLoading && state.items.isEmpty) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        itemCount: 6,
        itemBuilder: (context, index) => const SkeletonListTile(),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          EmptyState(
            icon: Icons.wifi_off_rounded,
            title: "Couldn't load notifications",
            subtitle: state.error,
            action: TextButton(onPressed: controller.refresh, child: const Text('Retry')),
          ),
        ],
      );
    }

    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          EmptyState(
            icon: Icons.notifications_none_rounded,
            title: "You're all caught up.",
            subtitle: "We'll let you know when there's something new.",
          ),
        ],
      );
    }

    final buckets = <String, List<AppNotification>>{'Today': [], 'Yesterday': [], 'Earlier': []};
    for (final n in state.items) {
      buckets[dayBucket(n.createdAt)]!.add(n);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      children: [
        for (final entry in buckets.entries)
          if (entry.value.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                entry.key,
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted),
              ),
            ),
            for (final notification in entry.value)
              _NotificationTile(
                notification: notification,
                onTap: () => controller.markRead(notification.id),
                onDismiss: () => controller.dismiss(notification.id),
              ),
          ],
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationTile({required this.notification, required this.onTap, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(color: AppColors.dangerPale, borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: cardShadow(opacity: 0.03),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(color: AppColors.paleGreen, shape: BoxShape.circle),
                child: Icon(_iconForType(notification.type), color: AppColors.accentGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.message,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.textSecondary, height: 1.3),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatTime(notification.createdAt),
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(color: AppColors.accentGreen, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
