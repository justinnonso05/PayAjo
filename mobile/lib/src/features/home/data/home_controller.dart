import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../groups/data/group_models.dart';
import '../../groups/data/group_repository.dart';

class HomeSummary {
  final UserGroupMembership membership;
  final GroupResponse group;
  final int memberCount;

  const HomeSummary({required this.membership, required this.group, this.memberCount = 0});
}

class HomeState {
  final bool isLoading;
  final String? error;
  final List<HomeSummary> summaries;

  const HomeState({this.isLoading = false, this.error, this.summaries = const []});

  bool get hasGroup => summaries.isNotEmpty;

  HomeState copyWith({bool? isLoading, String? error, List<HomeSummary>? summaries}) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      summaries: summaries ?? this.summaries,
    );
  }
}

/// Drives the Home tab's group card carousel. A user can belong to more
/// than one group, so this loads every membership (not just the first).
class HomeController extends Notifier<HomeState> {
  @override
  HomeState build() {
    Future.microtask(refresh);
    return const HomeState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final groupRepo = ref.read(groupRepositoryProvider);
      final memberships = await groupRepo.getMyGroups();

      if (memberships.isEmpty) {
        state = const HomeState(isLoading: false, summaries: []);
        return;
      }

      final summaries = await Future.wait(memberships.map((membership) async {
        final group = await groupRepo.getGroup(membership.groupId);
        final memberCount = await groupRepo.getMemberCount(membership.groupId);
        return HomeSummary(membership: membership, group: group, memberCount: memberCount);
      }));

      state = HomeState(isLoading: false, summaries: summaries);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }
}

final homeControllerProvider = NotifierProvider<HomeController, HomeState>(HomeController.new);
