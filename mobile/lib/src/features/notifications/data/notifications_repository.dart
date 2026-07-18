import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'notification_model.dart';

class NotificationsRepository {
  final ApiClient _apiClient;
  final SecureStorageService _secureStorage;

  NotificationsRepository({
    required ApiClient apiClient,
    required SecureStorageService secureStorage,
  })  : _apiClient = apiClient,
        _secureStorage = secureStorage;

  Future<List<AppNotification>> fetchNotifications() async {
    final response = await _apiClient.get(ApiConstants.notifications, headers: await _secureStorage.authHeaders());
    final data = response['data'];
    if (data is! List) return [];
    final items = data.whereType<Map<String, dynamic>>().map(AppNotification.fromJson).toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  /// Marks the given notification ids as read. Note: there's no delete
  /// endpoint yet, so "swipe to delete" in the UI is a local-only dismiss.
  Future<void> markRead(List<String> ids) async {
    await _apiClient.post(
      ApiConstants.markNotificationsRead,
      body: {'notification_ids': ids},
      headers: await _secureStorage.authHeaders(),
    );
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(
    apiClient: ref.watch(apiClientProvider),
    secureStorage: ref.watch(secureStorageServiceProvider),
  );
});

class NotificationsState {
  final List<AppNotification> items;
  final bool isLoading;
  final String? error;

  const NotificationsState({this.items = const [], this.isLoading = false, this.error});

  NotificationsState copyWith({List<AppNotification>? items, bool? isLoading, String? error}) {
    return NotificationsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class NotificationsController extends Notifier<NotificationsState> {
  @override
  NotificationsState build() {
    Future.microtask(refresh);
    return const NotificationsState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await ref.read(notificationsRepositoryProvider).fetchNotifications();
      state = NotificationsState(items: items, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  Future<void> markRead(String id) async {
    final target = state.items.where((n) => n.id == id);
    if (target.isEmpty || target.first.isRead) return;

    state = state.copyWith(
      items: [
        for (final n in state.items)
          if (n.id == id) n.copyWith(isRead: true) else n,
      ],
    );
    try {
      await ref.read(notificationsRepositoryProvider).markRead([id]);
    } on ApiException {
      // Best-effort — keep the optimistic read state either way.
    }
  }

  Future<void> markAllRead() async {
    final unreadIds = state.items.where((n) => !n.isRead).map((n) => n.id).toList();
    if (unreadIds.isEmpty) return;

    state = state.copyWith(items: [for (final n in state.items) n.copyWith(isRead: true)]);
    try {
      await ref.read(notificationsRepositoryProvider).markRead(unreadIds);
    } on ApiException {
      // Best-effort.
    }
  }

  /// Local-only dismiss — there is no delete endpoint on the backend yet.
  void dismiss(String id) {
    state = state.copyWith(items: state.items.where((n) => n.id != id).toList());
  }
}

final notificationsControllerProvider = NotifierProvider<NotificationsController, NotificationsState>(
  NotificationsController.new,
);

final hasUnreadNotificationsProvider = Provider<bool>((ref) {
  return ref.watch(notificationsControllerProvider).items.any((n) => !n.isRead);
});
