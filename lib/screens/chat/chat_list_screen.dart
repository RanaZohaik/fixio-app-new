import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../services/chat_service.dart';
import '../chat/chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ChatService _svc = ChatService();
  late AnimationController _animCtrl;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _svc.updatePresence(true);
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _svc.updatePresence(true);
    } else if (state == AppLifecycleState.paused) {
      _svc.updatePresence(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(child: _buildChatList()),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                StreamBuilder<QuerySnapshot>(
                  stream: _svc.myChatsStream(),
                  builder: (context, snap) {
                    final all = snap.data?.docs ?? [];
                    final active = all.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final deleted = data['deletedBy'] as Map? ?? {};
                      final archived = List<String>.from(
                          data['archivedBy'] as List? ?? []);
                      return !deleted.containsKey(_svc.myId) &&
                          !archived.contains(_svc.myId);
                    }).length;
                    return Text(
                      active == 0
                          ? 'No conversations'
                          : '$active conversation${active > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          StreamBuilder<bool>(
            stream: _svc.presenceStream(_svc.myId),
            builder: (context, snap) {
              final online = snap.data ?? true;
              return _OnlinePill(online: online);
            },
          ),
        ],
      ),
    );
  }

  // ── Chat List ─────────────────────────────────────────────────────────────
  Widget _buildChatList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _svc.myChatsStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryBlue,
              strokeWidth: 2.5,
            ),
          );
        }

        final all = snap.data?.docs ?? [];

        final active = <QueryDocumentSnapshot>[];
        final archived = <QueryDocumentSnapshot>[];

        for (final doc in all) {
          final data = doc.data() as Map<String, dynamic>;
          final deleted = data['deletedBy'] as Map? ?? {};
          if (deleted.containsKey(_svc.myId)) continue;

          final archivedBy =
          List<String>.from(data['archivedBy'] as List? ?? []);
          if (archivedBy.contains(_svc.myId)) {
            archived.add(doc);
          } else {
            active.add(doc);
          }
        }

        if (active.isEmpty && archived.isEmpty) {
          return _buildEmptyState();
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ...active.asMap().entries.map((entry) {
              final i = entry.key;
              final delay = i * 0.08;
              final anim = CurvedAnimation(
                parent: _animCtrl,
                curve: Interval(
                  delay.clamp(0.0, 0.8),
                  (delay + 0.4).clamp(0.0, 1.0),
                  curve: Curves.easeOut,
                ),
              );
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.12),
                    end: Offset.zero,
                  ).animate(anim),
                  child: _buildChatTile(entry.value, isArchived: false),
                ),
              );
            }),

            if (archived.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildArchivedToggle(archived.length),
              if (_showArchived)
                ...archived
                    .map((doc) => _buildChatTile(doc, isArchived: true)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildArchivedToggle(int count) {
    return GestureDetector(
      onTap: () => setState(() => _showArchived = !_showArchived),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.archive_outlined,
                  size: 18, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(width: 12),
            Text(
              'Archived  ($count)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            AnimatedRotation(
              turns: _showArchived ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 250),
              child:
              Icon(Icons.expand_more_rounded, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // ── Chat Tile ─────────────────────────────────────────────────────────────
  Widget _buildChatTile(QueryDocumentSnapshot doc, {required bool isArchived}) {
    final data = doc.data() as Map<String, dynamic>;
    final names = Map<String, String>.from(data['names'] as Map? ?? {});
    final participants = (data['participants'] as List? ?? []);
    final otherId = participants.firstWhere(
          (id) => id != _svc.myId,
      orElse: () => '',
    );
    if (otherId.isEmpty) return const SizedBox.shrink();

    final otherName = names[otherId] ?? 'User';
    final ts = data['lastMessageTime'] as Timestamp?;
    final time = ts != null ? _fmt(ts.toDate()) : '';
    final isToday =
        ts != null && DateTime.now().difference(ts.toDate()).inDays == 0;
    final isMuted =
    List<String>.from(data['mutedBy'] as List? ?? []).contains(_svc.myId);

    final avatarColors = [
      AppColors.primaryBlue,
      AppColors.accentOrange,
      const Color(0xFF7C3AED),
      const Color(0xFF059669),
      const Color(0xFFDC2626),
      const Color(0xFF0891B2),
    ];
    final avatarColor = otherName.isNotEmpty
        ? avatarColors[otherName.codeUnitAt(0) % avatarColors.length]
        : avatarColors[0];

    return Dismissible(
      key: Key(doc.id),
      background: _swipeBg(
        alignment: Alignment.centerLeft,
        color: isArchived ? AppColors.primaryBlue : const Color(0xFF7C3AED),
        icon: isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
        label: isArchived ? 'Unarchive' : 'Archive',
      ),
      secondaryBackground: _swipeBg(
        alignment: Alignment.centerRight,
        color: Colors.red.shade600,
        icon: Icons.delete_outline_rounded,
        label: 'Delete',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          isArchived
              ? await _svc.unarchiveChat(doc.id)
              : await _svc.archiveChat(doc.id);
          if (!isArchived && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              _snackBar(
                'Chat archived',
                action: TextButton(
                  onPressed: () => _svc.unarchiveChat(doc.id),
                  child: const Text('UNDO',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
            );
          }
          return false;
        } else {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => _ConfirmDialog(
              title: 'Delete Chat?',
              body: 'This chat will be hidden from your list.',
              confirmLabel: 'Delete',
              confirmColor: Colors.red,
            ),
          );
          if (confirm == true) await _svc.deleteChatForMe(doc.id);
          return false;
        }
      },
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _showChatOptions(context, doc.id, otherName,
              isArchived: isArchived, isMuted: isMuted);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatRoomScreen(
                    chatId: doc.id,
                    otherUserId: otherId,
                    otherUserName: otherName,
                  ),
                ),
              ),
              child: StreamBuilder<String>(
                stream: _svc.effectiveLastMessageStream(doc.id),
                builder: (context, lastMsgSnap) {
                  final lastMsg = lastMsgSnap.data ?? '';

                  return StreamBuilder<int>(
                    stream: _svc.unreadCountStream(doc.id),
                    builder: (context, unreadSnap) {
                      final unread = unreadSnap.data ?? 0;
                      final hasUnread = unread > 0;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isArchived
                              ? AppColors.surface.withOpacity(0.6)
                              : hasUnread
                              ? AppColors.primaryBlue.withOpacity(0.04)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: hasUnread
                                ? AppColors.primaryBlue.withOpacity(0.25)
                                : AppColors.border.withOpacity(0.6),
                            width: hasUnread ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Avatar with live online indicator
                            StreamBuilder<bool>(
                              stream: _svc.presenceStream(otherId),
                              builder: (context, presSnap) {
                                final online = presSnap.data ?? false;
                                return _ChatAvatar(
                                  name: otherName,
                                  color: isArchived ? Colors.grey : avatarColor,
                                  online: online,
                                  isArchived: isArchived,
                                );
                              },
                            ),
                            const SizedBox(width: 14),

                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Name row
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            otherName,
                                            style: TextStyle(
                                              fontWeight: hasUnread
                                                  ? FontWeight.w800
                                                  : FontWeight.w700,
                                              fontSize: 15,
                                              color: isArchived
                                                  ? AppColors.textSecondary
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                          if (isMuted) ...[
                                            const SizedBox(width: 5),
                                            Icon(
                                              Icons.volume_off_rounded,
                                              size: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                          ],
                                        ],
                                      ),
                                      _TimeChip(time: time, isToday: isToday),
                                    ],
                                  ),
                                  const SizedBox(height: 5),

                                  // Last message / typing indicator row
                                  // FIX: Left-aligned last message
                                  StreamBuilder<bool>(
                                    stream: _svc.isOtherTypingStream(
                                        doc.id, otherId),
                                    builder: (ctx, typingSnap) {
                                      final isTyping = typingSnap.data ?? false;

                                      return Row(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: AnimatedSwitcher(
                                              duration: const Duration(
                                                  milliseconds: 250),
                                              child: isTyping
                                                  ? Row(
                                                key: const ValueKey(
                                                    'typing'),
                                                mainAxisSize:
                                                MainAxisSize.min,
                                                mainAxisAlignment:
                                                MainAxisAlignment
                                                    .start,
                                                children: [
                                                  Text(
                                                    'typing',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: AppColors
                                                          .successGreen,
                                                      fontStyle: FontStyle
                                                          .italic,
                                                      fontWeight:
                                                      FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  _MiniTypingDots(),
                                                ],
                                              )
                                                  : Align(
                                                // FIX: left-aligned text
                                                alignment:
                                                Alignment.centerLeft,
                                                child: Text(
                                                  key: const ValueKey(
                                                      'msg'),
                                                  lastMsg.isEmpty
                                                      ? 'Tap to start chatting'
                                                      : lastMsg,
                                                  maxLines: 1,
                                                  overflow: TextOverflow
                                                      .ellipsis,
                                                  textAlign: TextAlign.left,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: hasUnread
                                                        ? AppColors
                                                        .textPrimary
                                                        : lastMsg.isEmpty
                                                        ? AppColors
                                                        .textSecondary
                                                        .withOpacity(
                                                        0.5)
                                                        : AppColors
                                                        .textSecondary,
                                                    fontWeight: hasUnread
                                                        ? FontWeight.w600
                                                        : FontWeight.normal,
                                                    fontStyle:
                                                    lastMsg.isEmpty
                                                        ? FontStyle
                                                        .italic
                                                        : FontStyle
                                                        .normal,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (hasUnread && !isMuted)
                                            _UnreadBadge(count: unread)
                                          else
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              size: 18,
                                              color: AppColors.textSecondary
                                                  .withOpacity(0.35),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _swipeBg({
    required AlignmentGeometry alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: alignment == Alignment.centerLeft
              ? Alignment.centerLeft
              : Alignment.centerRight,
          end: alignment == Alignment.centerLeft
              ? Alignment.centerRight
              : Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _showChatOptions(
      BuildContext context,
      String chatId,
      String otherName, {
        required bool isArchived,
        required bool isMuted,
      }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChatOptionsSheet(
        otherName: otherName,
        isArchived: isArchived,
        isMuted: isMuted,
        onArchive: () async {
          Navigator.pop(ctx);
          isArchived
              ? await _svc.unarchiveChat(chatId)
              : await _svc.archiveChat(chatId);
        },
        onMute: () async {
          Navigator.pop(ctx);
          isMuted
              ? await _svc.unmuteChat(chatId)
              : await _svc.muteChat(chatId);
        },
        onDelete: () async {
          Navigator.pop(ctx);
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => _ConfirmDialog(
              title: 'Delete Chat?',
              body: 'This will hide the chat from your list.',
              confirmLabel: 'Delete',
              confirmColor: Colors.red,
            ),
          );
          if (confirm == true) await _svc.deleteChatForMe(chatId);
        },
        onClear: () async {
          Navigator.pop(ctx);
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => _ConfirmDialog(
              title: 'Clear Chat?',
              body: 'All messages will be cleared for you only.',
              confirmLabel: 'Clear',
              confirmColor: AppColors.accentOrange,
            ),
          );
          if (confirm == true) await _svc.clearChatForMe(chatId);
        },
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (_, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryBlue.withOpacity(0.15),
                      AppColors.accentOrange.withOpacity(0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AppColors.primaryBlue.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 40,
                  color: AppColors.primaryBlue.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Browse items and tap\n"Chat with Vendor" to start',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  SnackBar _snackBar(String msg, {Widget? action}) => SnackBar(
    content:
    Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
    behavior: SnackBarBehavior.floating,
    backgroundColor: AppColors.primaryBlueDark,
    shape:
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  String _fmt(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 30) return 'Just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }
}

// ─── Mini typing dots for chat list ──────────────────────────────────────────
class _MiniTypingDots extends StatefulWidget {
  @override
  State<_MiniTypingDots> createState() => _MiniTypingDotsState();
}

class _MiniTypingDotsState extends State<_MiniTypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final value = ((_ctrl.value - delay + 1) % 1.0);
            final opacity = value < 0.5 ? value * 2 : (1 - value) * 2;
            return Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.successGreen.withOpacity(opacity),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─── Reusable sub-widgets ─────────────────────────────────────────────────────

class _OnlinePill extends StatelessWidget {
  final bool online;
  const _OnlinePill({required this.online});

  @override
  Widget build(BuildContext context) {
    final color = online ? AppColors.successGreen : AppColors.textSecondary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: online
                  ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)]
                  : [],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            online ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// FIX: Avatar now shows a vivid green dot when online, grey when offline.
class _ChatAvatar extends StatelessWidget {
  final String name;
  final Color color;
  final bool online;
  final bool isArchived;

  const _ChatAvatar({
    required this.name,
    required this.color,
    required this.online,
    required this.isArchived,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(isArchived ? 0.5 : 0.85),
                color.withOpacity(isArchived ? 0.3 : 0.55),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
        ),
        // FIX: Always visible online/offline dot with strong contrast
        Positioned(
          right: -2,
          bottom: -2,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: online ? AppColors.successGreen : Colors.grey.shade400,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.background,
                width: 2.5,
              ),
              boxShadow: online
                  ? [
                BoxShadow(
                  color: AppColors.successGreen.withOpacity(0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                )
              ]
                  : [],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String time;
  final bool isToday;
  const _TimeChip({required this.time, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.primaryBlue.withOpacity(0.1)
            : AppColors.border.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        time,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isToday ? AppColors.primaryBlue : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, Color(0xFF1565C0)],
        ),
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Chat Options Bottom Sheet ─────────────────────────────────────────────────
class _ChatOptionsSheet extends StatelessWidget {
  final String otherName;
  final bool isArchived;
  final bool isMuted;
  final VoidCallback onArchive;
  final VoidCallback onMute;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  const _ChatOptionsSheet({
    required this.otherName,
    required this.isArchived,
    required this.isMuted,
    required this.onArchive,
    required this.onMute,
    required this.onDelete,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              otherName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: AppColors.border),
          _Option(
            icon: isArchived
                ? Icons.unarchive_outlined
                : Icons.archive_outlined,
            label: isArchived ? 'Unarchive' : 'Archive Chat',
            color: const Color(0xFF7C3AED),
            onTap: onArchive,
          ),
          _Option(
            icon: isMuted
                ? Icons.volume_up_outlined
                : Icons.volume_off_outlined,
            label: isMuted ? 'Unmute Chat' : 'Mute Notifications',
            color: AppColors.primaryBlue,
            onTap: onMute,
          ),
          _Option(
            icon: Icons.cleaning_services_outlined,
            label: 'Clear Chat',
            color: AppColors.accentOrange,
            onTap: onClear,
          ),
          _Option(
            icon: Icons.delete_outline_rounded,
            label: 'Delete Chat',
            color: Colors.red,
            onTap: onDelete,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _Option({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color:
          label.contains('Delete') ? Colors.red : AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ── Confirm Dialog ────────────────────────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirmLabel;
  final Color confirmColor;

  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      content: Text(body,
          style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(confirmLabel,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}