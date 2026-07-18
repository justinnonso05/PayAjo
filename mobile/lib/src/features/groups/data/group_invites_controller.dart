import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import 'group_models.dart';
import 'group_repository.dart';

/// An invite paired with its group's display name — the invite endpoint
/// itself only returns raw ids, so this resolves the name separately.
class GroupInviteWithGroup {
  final GroupInvite invite;
  final String groupName;

  const GroupInviteWithGroup({required this.invite, required this.groupName});
}

class GroupInvitesState {
  final List<GroupInviteWithGroup> invites;
  final bool isLoading;
  final String? error;

  const GroupInvitesState({this.invites = const [], this.isLoading = false, this.error});

  GroupInvitesState copyWith({List<GroupInviteWithGroup>? invites, bool? isLoading, String? error}) {
    return GroupInvitesState(
      invites: invites ?? this.invites,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class GroupInvitesController extends Notifier<GroupInvitesState> {
  @override
  GroupInvitesState build() {
    Future.microtask(refresh);
    return const GroupInvitesState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final groupRepo = ref.read(groupRepositoryProvider);
      final invites = (await groupRepo.getMyInvites()).where((i) => i.isPending).toList();

      final withNames = await Future.wait(invites.map((invite) async {
        try {
          final group = await groupRepo.getGroup(invite.groupId);
          return GroupInviteWithGroup(invite: invite, groupName: group.name);
        } on ApiException {
          return GroupInviteWithGroup(invite: invite, groupName: 'A savings group');
        }
      }));

      state = GroupInvitesState(invites: withNames, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  Future<void> respond(String inviteId, {required bool accept}) async {
    await ref.read(groupRepositoryProvider).respondToInvite(inviteId, accept: accept);
    await refresh();
  }
}

final groupInvitesControllerProvider = NotifierProvider<GroupInvitesController, GroupInvitesState>(
  GroupInvitesController.new,
);
