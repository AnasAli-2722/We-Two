import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme_engine.dart';
import '../../../core/widgets/shimmer_skeleton.dart';
import '../application/chat_models.dart';
import '../application/duo_state_notifier.dart';
import '../application/message_stream_provider.dart';
import '../data/chat_repository.dart';
import '../../notifications/notification_service.dart';
import '../../notifications/application/in_app_notifications_provider.dart';
import '../../profiles/data/profile_repository.dart';
import '../../profiles/models/profile.dart';
import 'contact_sheet.dart';

// Using `NotificationService.forceRefreshTrigger` directly instead of a
// `ValueListenableProvider` to avoid depending on a provider API that may
// not be available in the project's Riverpod version.

final _chatPeerProfileProvider = FutureProvider.autoDispose<Profile?>((
  ref,
) async {
  final duoState = ref.watch(duoStateProvider).valueOrNull;
  final peerId = duoState?.activePartnerId;
  if (peerId == null || peerId.isEmpty) {
    return null;
  }

  return ref.watch(profileRepositoryProvider).getProfileById(peerId);
});

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _messagesController = ScrollController();
  final List<ChatMessage> _optimisticMessages = <ChatMessage>[];
  bool _hasText = false;
  ChatMessage? _replyingTo;
  late final VoidCallback _removeForceRefreshListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(ref.read(notificationServiceProvider).clearAllNotifications());
    _composerController.addListener(_handleComposerChanged);

    // Listen directly to the `ValueNotifier` exposed by NotificationService.
    void _onForceRefresh() {
      if (!mounted) return;
      ref.invalidate(messageStreamProvider);
    }

    NotificationService.forceRefreshTrigger.addListener(_onForceRefresh);
    _removeForceRefreshListener = () {
      NotificationService.forceRefreshTrigger.removeListener(_onForceRefresh);
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(notificationServiceProvider).clearAllNotifications());
      ref.invalidate(messageStreamProvider);
    }
  }

  void _handleComposerChanged() {
    final hasText = _composerController.text.trim().isNotEmpty;
    if (hasText != _hasText && mounted) {
      setState(() => _hasText = hasText);
    }
  }

  void _scrollToLatest() {
    if (!_messagesController.hasClients) {
      return;
    }
    _messagesController.animateTo(
      0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  bool _matchesOptimistic(ChatMessage remote, ChatMessage local) {
    final sameSender = remote.senderId == local.senderId;
    final sameReceiver = remote.receiverId == local.receiverId;
    final sameContent = remote.content.trim() == local.content.trim();
    final sameReplyTo = remote.replyToId == local.replyToId;
    final timeDeltaSeconds = remote.createdAt
        .difference(local.createdAt)
        .inSeconds
        .abs();
    return sameSender &&
        sameReceiver &&
        sameContent &&
        sameReplyTo &&
        timeDeltaSeconds <= 15;
  }

  List<ChatMessage> _buildDisplayMessages(List<ChatMessage> streamMessages) {
    if (_optimisticMessages.isEmpty) {
      return streamMessages;
    }

    final pending = <ChatMessage>[];
    var changed = false;
    for (final optimistic in _optimisticMessages) {
      if (optimistic.isFailed) {
        pending.add(optimistic);
        continue;
      }

      final hasServerMatch = streamMessages.any(
        (remote) => _matchesOptimistic(remote, optimistic),
      );
      if (hasServerMatch) {
        changed = true;
        continue;
      }
      pending.add(optimistic);
    }

    if (changed && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _optimisticMessages
            ..clear()
            ..addAll(pending);
        });
      });
    }

    final merged = <ChatMessage>[...streamMessages, ...pending];
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  Future<void> _sendMessageInBackground({
    required ChatMessage optimisticMessage,
  }) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            senderId: optimisticMessage.senderId,
            receiverId: optimisticMessage.receiverId,
            content: optimisticMessage.content,
            replyToId: optimisticMessage.replyToId,
            createdAt: optimisticMessage.createdAt,
          );
      if (!mounted) {
        return;
      }
      ref.invalidate(messageStreamProvider);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        final index = _optimisticMessages.indexWhere(
          (item) => item.id == optimisticMessage.id,
        );
        if (index == -1) {
          return;
        }
        _optimisticMessages[index] = _optimisticMessages[index].copyWith(
          deliveryStatus: MessageDeliveryStatus.failed,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message failed. Tap it to retry.')),
      );
    }
  }

  Future<void> _retryFailedOptimisticMessage(String messageId) async {
    final index = _optimisticMessages.indexWhere(
      (item) => item.id == messageId,
    );
    if (index == -1) {
      return;
    }

    final current = _optimisticMessages[index];
    if (!current.isFailed) {
      return;
    }

    final retryMessage = current.copyWith(
      createdAt: DateTime.now().toUtc(),
      deliveryStatus: MessageDeliveryStatus.sending,
    );

    setState(() {
      _optimisticMessages[index] = retryMessage;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _scrollToLatest();
    });

    await _sendMessageInBackground(optimisticMessage: retryMessage);
  }

  @override
  void dispose() {
    NotificationService.clearActiveChat();
    _removeForceRefreshListener();
    WidgetsBinding.instance.removeObserver(this);
    _composerController.removeListener(_handleComposerChanged);
    _composerController.dispose();
    _messagesController.dispose();
    super.dispose();
  }

  Future<void> _openContactsSheet() async {
    final duoState = ref.read(duoStateProvider).valueOrNull;
    final currentUserId = duoState?.currentUserId;
    final previousPartnerId = duoState?.activePartnerId;
    final theme = Theme.of(context);
    final appColors = theme.extension<WeTwoThemeColors>();
    final background = appColors?.background ?? theme.scaffoldBackgroundColor;
    if (currentUserId == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: background,
      isScrollControlled: true,
      builder: (context) => ContactSheet(currentUserId: currentUserId),
    );

    final updatedPartnerId = ref
        .read(duoStateProvider)
        .valueOrNull
        ?.activePartnerId;
    if (updatedPartnerId != previousPartnerId && mounted) {
      _composerController.clear();
      setState(() {
        _replyingTo = null;
        _optimisticMessages.clear();
      });
      ref.invalidate(messageStreamProvider);
    }
  }

  Future<void> _sendMessage() async {
    final duoState = ref.read(duoStateProvider).valueOrNull;
    final currentUserId = duoState?.currentUserId;
    final activePartnerId = duoState?.activePartnerId;
    final content = _composerController.text.trim();

    if (currentUserId == null || activePartnerId == null || content.isEmpty) {
      return;
    }

    final optimisticMessage = ChatMessage(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      senderId: currentUserId,
      receiverId: activePartnerId,
      content: content,
      createdAt: DateTime.now().toUtc(),
      replyToId: _replyingTo?.id,
      deliveryStatus: MessageDeliveryStatus.sending,
    );

    await HapticFeedback.lightImpact();
    _composerController.clear();
    setState(() {
      _replyingTo = null;
      _optimisticMessages.add(optimisticMessage);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _scrollToLatest();
    });

    _sendMessageInBackground(optimisticMessage: optimisticMessage);
  }

  String _peerDisplayName(Profile? peer) {
    final firstName = peer?.firstName?.trim();
    if (firstName != null && firstName.isNotEmpty) {
      return firstName;
    }
    final username = peer?.username.trim();
    if (username != null && username.isNotEmpty) {
      return username;
    }
    return 'Conversation';
  }

  Widget _buildMessagesList({
    required List<ChatMessage> messages,
    required String? currentUserId,
  }) {
    final displayMessages = _buildDisplayMessages(messages);

    if (displayMessages.isEmpty) {
      return const Center(
        child: Text('No messages yet', style: TextStyle(color: Colors.white54)),
      );
    }

    final messageById = {for (final item in displayMessages) item.id: item};

    return ListView.builder(
      controller: _messagesController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      itemCount: displayMessages.length,
      itemBuilder: (context, index) {
        final message = displayMessages[index];
        final repliedMessage = message.replyToId == null
            ? null
            : messageById[message.replyToId!];
        final isMine = message.senderId == currentUserId;

        return _SwipeToReply(
          key: ValueKey(message.id),
          onReply: () {
            HapticFeedback.selectionClick();
            setState(() => _replyingTo = message);
          },
          child: _MessageBubble(
            message: message,
            repliedMessage: repliedMessage,
            isMine: isMine,
            onRetry: message.isFailed && isMine
                ? () => _retryFailedOptimisticMessage(message.id)
                : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final duoStateAsync = ref.watch(duoStateProvider);
    final duoState = duoStateAsync.value;
    final peerProfile = ref.watch(_chatPeerProfileProvider).valueOrNull;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    NotificationService.setActiveChatId(duoState?.activePartnerId);
    final messagesAsync = ref.watch(messageStreamProvider);
    final staleMessages = messagesAsync.valueOrNull;
    final theme = Theme.of(context);
    final appColors = theme.extension<WeTwoThemeColors>();
    final accent = appColors?.accent ?? theme.colorScheme.primary;
    final surface = appColors?.surface ?? theme.colorScheme.surface;
    final background = appColors?.background ?? theme.scaffoldBackgroundColor;
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final composerBottomInset = isKeyboardOpen
        ? 0.0
        : 12.0 + MediaQuery.paddingOf(context).bottom + 66.0;
    final peerName = _peerDisplayName(peerProfile);
    final peerAvatarUrl = peerProfile?.avatarUrl;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: !isKeyboardOpen,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      final navigator = Navigator.of(context);
                      if (navigator.canPop()) {
                        navigator.pop();
                        return;
                      }
                      _openContactsSheet();
                    },
                    tooltip: 'Back',
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: const Color(0xFF252533),
                    backgroundImage:
                        peerAvatarUrl != null && peerAvatarUrl.isNotEmpty
                        ? NetworkImage(peerAvatarUrl)
                        : null,
                    child: peerAvatarUrl == null || peerAvatarUrl.isEmpty
                        ? Icon(Icons.person_rounded, color: accent, size: 20)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      peerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _openContactsSheet,
                    tooltip: 'Change duo',
                    icon: Icon(Icons.people_outline_rounded, color: accent),
                  ),
                ],
              ),
            ),
            Expanded(
              child: messagesAsync.when(
                skipLoadingOnRefresh: true,
                skipLoadingOnReload: true,
                data: (messages) => _buildMessagesList(
                  messages: messages,
                  currentUserId: currentUserId,
                ),
                loading: () {
                  if (staleMessages != null) {
                    return _buildMessagesList(
                      messages: staleMessages,
                      currentUserId: currentUserId,
                    );
                  }
                  return const _ChatMessagesShimmer();
                },
                error: (error, stack) => Center(
                  child: Text(
                    'Failed to load messages',
                    style: TextStyle(color: accent),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, composerBottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _replyingTo == null
                        ? const SizedBox.shrink()
                        : Container(
                            key: const ValueKey('reply-preview'),
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Replying to: ${_replyingTo!.content}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _replyingTo = null);
                                  },
                                  tooltip: 'Cancel reply',
                                  icon: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _composerController,
                            style: const TextStyle(color: Colors.white),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                            decoration: const InputDecoration(
                              hintText: 'Message',
                              hintStyle: TextStyle(color: Colors.white38),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.fromLTRB(
                                18,
                                11,
                                6,
                                11,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 140),
                            scale: _hasText ? 1 : 0.92,
                            curve: Curves.easeOut,
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: _hasText
                                    ? accent
                                    : accent.withValues(alpha: 0.35),
                                foregroundColor: Colors.black,
                                disabledBackgroundColor: accent.withValues(
                                  alpha: 0.25,
                                ),
                                disabledForegroundColor: Colors.black
                                    .withValues(alpha: 0.35),
                              ),
                              onPressed: _hasText ? _sendMessage : null,
                              tooltip: 'Send message',
                              icon: const Icon(Icons.arrow_upward_rounded),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({super.key, required this.child, required this.onReply});

  final Widget child;
  final VoidCallback onReply;

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  static const double _triggerDistance = 56;
  static const double _maxVisualOffset = 18;
  double _dragExtent = 0;

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent += details.delta.dx;
      _dragExtent = _dragExtent.clamp(-96.0, 96.0);
    });
  }

  void _resetDrag() {
    if (_dragExtent == 0) {
      return;
    }
    setState(() => _dragExtent = 0);
  }

  void _handleDragEnd(DragEndDetails details) {
    final shouldReply = _dragExtent.abs() >= _triggerDistance;
    _resetDrag();
    if (shouldReply) {
      widget.onReply();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<WeTwoThemeColors>();
    final cueColor = (appColors?.accent ?? theme.colorScheme.primary)
        .withValues(alpha: 0.85);

    final hasDrag = _dragExtent != 0;
    final cueOnRight = _dragExtent > 0;
    final progress = (_dragExtent.abs() / _triggerDistance).clamp(0.0, 1.0);
    final childOffset = (_dragExtent * 0.22).clamp(
      -_maxVisualOffset,
      _maxVisualOffset,
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      onHorizontalDragCancel: _resetDrag,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (hasDrag)
            Positioned(
              left: cueOnRight ? null : 8,
              right: cueOnRight ? 8 : null,
              child: Opacity(
                opacity: 0.25 + (progress * 0.55),
                child: Transform.scale(
                  scale: 0.9 + (progress * 0.2),
                  child: Icon(Icons.reply_rounded, size: 18, color: cueColor),
                ),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(childOffset, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _ChatMessagesShimmer extends StatelessWidget {
  const _ChatMessagesShimmer();

  @override
  Widget build(BuildContext context) {
    return ShimmerSkeleton(
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.all(16),
        itemCount: 7,
        itemBuilder: (context, index) {
          final isMine = index.isEven;
          return Align(
            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                width: isMine ? 180 : 220,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMine ? 20 : 4),
                    bottomRight: Radius.circular(isMine ? 4 : 20),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    this.repliedMessage,
    this.onRetry,
  });

  final ChatMessage message;
  final bool isMine;
  final ChatMessage? repliedMessage;
  final VoidCallback? onRetry;

  String _timeText(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<WeTwoThemeColors>();
    final accent = appColors?.accent ?? theme.colorScheme.primary;
    final surface = appColors?.surface ?? theme.colorScheme.surface;
    final bubbleColor = isMine ? accent.withValues(alpha: 0.9) : surface;
    final textColor = isMine ? const Color(0xFF121212) : Colors.white;
    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(isMine ? 20 : 4),
      bottomRight: Radius.circular(isMine ? 4 : 20),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onRetry,
              borderRadius: bubbleRadius,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: bubbleRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (repliedMessage != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(10, 8, 10, 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isMine
                              ? Colors.black.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border(
                            left: BorderSide(color: accent, width: 3),
                          ),
                        ),
                        child: Text(
                          repliedMessage!.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.78),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.content,
                            style: TextStyle(color: textColor, height: 1.35),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _timeText(message.createdAt),
                                style: TextStyle(
                                  color: textColor.withValues(alpha: 0.62),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (isMine) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  message.deliveryStatus ==
                                          MessageDeliveryStatus.sending
                                      ? Icons.schedule_rounded
                                      : message.deliveryStatus ==
                                            MessageDeliveryStatus.failed
                                      ? Icons.error_outline_rounded
                                      : Icons.check_rounded,
                                  size: 13,
                                  color:
                                      message.deliveryStatus ==
                                          MessageDeliveryStatus.failed
                                      ? Colors.redAccent.shade100
                                      : textColor.withValues(alpha: 0.7),
                                ),
                              ],
                              if (message.isFailed && onRetry != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'Tap to retry',
                                  style: TextStyle(
                                    color: Colors.redAccent.shade100,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
