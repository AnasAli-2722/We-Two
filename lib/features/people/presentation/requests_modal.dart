import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme_engine.dart';
import '../application/discovery_notifier.dart';

class RequestsModal extends ConsumerWidget {
  const RequestsModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingRequestsProvider);
    final state = ref.watch(discoveryStateProvider);
    final notifier = ref.read(discoveryStateProvider.notifier);
    final theme = Theme.of(context);
    final appColors = theme.extension<WeTwoThemeColors>();
    final accent = appColors?.accent ?? theme.colorScheme.primary;
    final surface = appColors?.surface ?? theme.colorScheme.surface;

    return requestsAsync.when(
      loading: () => const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => SizedBox(
        height: 240,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load requests', style: TextStyle(color: accent)),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => ref.invalidate(pendingRequestsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return const SizedBox(
            height: 240,
            child: Center(
              child: Text(
                'No pending requests',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          );
        }

        return SizedBox(
          height: 420,
          child: ListView.separated(
            itemCount: requests.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, color: Colors.white12),
            itemBuilder: (context, index) {
              final request = requests[index];
              final isResponding = state.isRespondingToRequest(request.id);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: surface,
                  backgroundImage:
                      request.avatarUrl != null && request.avatarUrl!.isNotEmpty
                      ? NetworkImage(request.avatarUrl!)
                      : null,
                  child: request.avatarUrl == null || request.avatarUrl!.isEmpty
                      ? const Icon(Icons.person, color: Colors.white70)
                      : null,
                ),
                title: Text(
                  request.username,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: isResponding
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Wrap(
                        spacing: 6,
                        children: [
                          TextButton(
                            onPressed: () async {
                              await notifier.respondToRequest(
                                requestId: request.id,
                                accept: false,
                              );
                              if (!context.mounted) {
                                return;
                              }
                              final error = ref
                                  .read(discoveryStateProvider)
                                  .errorMessage;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error ?? 'Request declined'),
                                ),
                              );
                            },
                            child: const Text('Decline'),
                          ),
                          FilledButton(
                            onPressed: () async {
                              await notifier.respondToRequest(
                                requestId: request.id,
                                accept: true,
                              );
                              if (!context.mounted) {
                                return;
                              }
                              final error = ref
                                  .read(discoveryStateProvider)
                                  .errorMessage;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error ?? 'Request accepted'),
                                ),
                              );
                            },
                            child: const Text('Accept'),
                          ),
                        ],
                      ),
              );
            },
          ),
        );
      },
    );
  }
}
