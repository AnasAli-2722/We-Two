import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_error_reporter.dart';
import '../../auth/application/auth_state_provider.dart';
import '../../chat/application/duo_state_notifier.dart';
import 'friends_provider.dart';
import '../data/people_repository.dart';
import '../models/discovery_user.dart';
import '../models/partner_request.dart';

class DiscoveryUiState {
  const DiscoveryUiState({
    this.query = '',
    this.isActionLoading = false,
    this.sendingRequestToUserIds = const <String>{},
    this.respondingRequestIds = const <String>{},
    this.errorMessage,
  });

  final String query;
  final bool isActionLoading;
  final Set<String> sendingRequestToUserIds;
  final Set<String> respondingRequestIds;
  final String? errorMessage;

  bool isSendingRequestTo(String userId) =>
      sendingRequestToUserIds.contains(userId);
  bool isRespondingToRequest(String requestId) =>
      respondingRequestIds.contains(requestId);

  DiscoveryUiState copyWith({
    String? query,
    bool? isActionLoading,
    Set<String>? sendingRequestToUserIds,
    Set<String>? respondingRequestIds,
    String? errorMessage,
  }) {
    return DiscoveryUiState(
      query: query ?? this.query,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      sendingRequestToUserIds:
          sendingRequestToUserIds ?? this.sendingRequestToUserIds,
      respondingRequestIds: respondingRequestIds ?? this.respondingRequestIds,
      errorMessage: errorMessage,
    );
  }
}

final discoveryStateProvider =
    NotifierProvider.autoDispose<DiscoveryNotifier, DiscoveryUiState>(
      DiscoveryNotifier.new,
    );

class DiscoveryNotifier extends AutoDisposeNotifier<DiscoveryUiState> {
  @override
  DiscoveryUiState build() {
    return const DiscoveryUiState();
  }

  void setQuery(String value) {
    state = state.copyWith(query: value, errorMessage: null);
  }

  void clearQuery() {
    state = state.copyWith(query: '', errorMessage: null);
  }

  Future<void> sendRequest(String toUserId) async {
    final fromUserId = ref.read(authUserIdProvider);
    if (fromUserId == null) {
      state = state.copyWith(errorMessage: 'Not authenticated.');
      return;
    }

    if (state.isSendingRequestTo(toUserId)) {
      return;
    }

    final sendingIds = Set<String>.from(state.sendingRequestToUserIds)
      ..add(toUserId);
    state = state.copyWith(
      isActionLoading: true,
      sendingRequestToUserIds: sendingIds,
      errorMessage: null,
    );

    try {
      await ref
          .read(peopleRepositoryProvider)
          .sendPartnerRequest(fromUserId: fromUserId, toUserId: toUserId);
      ref.invalidate(outgoingPendingRequestUserIdsProvider);
      state = state.copyWith(errorMessage: null);
    } on PeopleActionException catch (error) {
      if (error.code == PeopleActionErrorCode.duplicate) {
        ref.invalidate(outgoingPendingRequestUserIdsProvider);
      }
      state = state.copyWith(errorMessage: error.message);
    } catch (error) {
      AppErrorReporter.report(
        error,
        feature: 'people',
        operation: 'sendRequest',
        context: <String, Object?>{'toUserId': toUserId},
      );
      state = state.copyWith(errorMessage: '$error');
    } finally {
      final updatedSendingIds = Set<String>.from(state.sendingRequestToUserIds)
        ..remove(toUserId);
      state = state.copyWith(
        isActionLoading: false,
        sendingRequestToUserIds: updatedSendingIds,
      );
    }
  }

  Future<void> respondToRequest({
    required String requestId,
    required bool accept,
  }) async {
    final currentUserId = ref.read(authUserIdProvider);
    if (currentUserId == null) {
      state = state.copyWith(errorMessage: 'Not authenticated.');
      return;
    }

    final inFlight = Set<String>.from(state.respondingRequestIds)
      ..add(requestId);
    state = state.copyWith(respondingRequestIds: inFlight, errorMessage: null);
    try {
      await ref
          .read(peopleRepositoryProvider)
          .respondToRequest(
            requestId: requestId,
            accept: accept,
            currentUserId: currentUserId,
          );

      ref.invalidate(pendingRequestsProvider);
      ref.invalidate(unseenRequestsCountProvider);
      ref.invalidate(friendsProvider);
      ref.invalidate(outgoingPendingRequestUserIdsProvider);
      ref.invalidate(duoStateProvider);
      state = state.copyWith(errorMessage: null);
    } on PeopleActionException catch (error) {
      state = state.copyWith(errorMessage: error.message);
    } catch (error) {
      AppErrorReporter.report(
        error,
        feature: 'people',
        operation: 'respondToRequest',
        context: <String, Object?>{'requestId': requestId, 'accept': accept},
      );
      state = state.copyWith(errorMessage: '$error');
    } finally {
      final updatedInFlight = Set<String>.from(state.respondingRequestIds)
        ..remove(requestId);
      state = state.copyWith(respondingRequestIds: updatedInFlight);
    }
  }

  Future<void> markRequestsSeen() async {
    final userId = ref.read(authUserIdProvider);
    if (userId == null) {
      return;
    }

    await ref.read(peopleRepositoryProvider).markRequestsSeen(userId);
    ref.invalidate(unseenRequestsCountProvider);
  }
}

final searchUsersProvider = FutureProvider.autoDispose
    .family<List<DiscoveryUser>, String>((ref, rawQuery) async {
      final query = rawQuery.trim();
      if (query.isEmpty) {
        return const [];
      }

      final userId = ref.watch(authUserIdProvider);
      if (userId == null) {
        return const [];
      }

      return ref
          .watch(peopleRepositoryProvider)
          .searchUsers(currentUserId: userId, searchText: query);
    });

final pendingRequestsProvider =
    FutureProvider.autoDispose<List<PartnerRequest>>((ref) async {
      final userId = ref.watch(authUserIdProvider);
      if (userId == null) {
        return const [];
      }

      return ref.watch(peopleRepositoryProvider).getPendingRequests(userId);
    });

final outgoingPendingRequestUserIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
      final userId = ref.watch(authUserIdProvider);
      if (userId == null) {
        return const <String>{};
      }

      return ref
          .watch(peopleRepositoryProvider)
          .getOutgoingPendingRequestUserIds(userId);
    });

final unseenRequestsCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null) {
    return 0;
  }

  return ref.watch(peopleRepositoryProvider).getUnseenRequestsCount(userId);
});
