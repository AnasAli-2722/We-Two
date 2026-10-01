import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme_engine.dart';
import '../../people/data/people_repository.dart';
import '../../profiles/models/profile.dart';
import '../application/duo_state_notifier.dart';

class ContactSheet extends ConsumerWidget {
  const ContactSheet({super.key, required this.currentUserId});

  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(_contactsProvider(currentUserId));
    final theme = Theme.of(context);
    final appColors = theme.extension<WeTwoThemeColors>();
    final accent = appColors?.accent ?? theme.colorScheme.primary;
    final surface = appColors?.surface ?? theme.colorScheme.surface;

    return SafeArea(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const Expanded(
                  child: Text(
                    'Change Duo',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: contactsAsync.when(
              data: (contacts) => contacts.isEmpty
                  ? const Center(
                      child: Text(
                        'No contacts available',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: contacts.length,
                      itemBuilder: (context, index) {
                        final contact = contacts[index];
                        return Card(
                          color: surface,
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: surface,
                              backgroundImage:
                                  contact.avatarUrl != null &&
                                      contact.avatarUrl!.isNotEmpty
                                  ? NetworkImage(contact.avatarUrl!)
                                  : null,
                              child:
                                  contact.avatarUrl == null ||
                                      contact.avatarUrl!.isEmpty
                                  ? Icon(Icons.person, color: accent)
                                  : null,
                            ),
                            title: Text(
                              contact.fullName.isEmpty
                                  ? contact.username
                                  : contact.fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '@${contact.username}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            onTap: () async {
                              await ref
                                  .read(duoStateProvider.notifier)
                                  .setActivePartner(contact.id);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  'Failed to load contacts: $error',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final _contactsProvider = FutureProvider.autoDispose
    .family<List<Profile>, String>((ref, userId) {
      return ref.watch(peopleRepositoryProvider).listAcceptedFriends(userId);
    });
