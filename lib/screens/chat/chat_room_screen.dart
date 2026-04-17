import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../services/chat_service.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final Map<String, dynamic>? itemContext;

  const ChatRoomScreen({
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.itemContext,
    super.key,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen>
    with WidgetsBindingObserver {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _svc = ChatService();

  Timestamp? _myClearedAt;
  StreamSubscription? _clearedAtSub;

  int _prevCount = 0;
  bool _itemCardDismissed = false;
  bool _itemRefSent = false;

  // ── Reply state ────────────────────────────────────────────────────────────
  Map<String, dynamic>? _replyTo;

  // ── Typing state ──────────────────────────────────────────────────────────
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _svc.updatePresence(true);
    _svc.markMessagesRead(widget.chatId);

    _clearedAtSub = _svc.myClearedAtStream(widget.chatId).listen((ts) {
      if (mounted) setState(() => _myClearedAt = ts);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _svc.updatePresence(true);
      _svc.markMessagesRead(widget.chatId);
    } else if (state == AppLifecycleState.paused) {
      _svc.updatePresence(false);
      _svc.setTyping(widget.chatId, false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _svc.setTyping(widget.chatId, false);
    _typingTimer?.cancel();
    _clearedAtSub?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool jump = false}) {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    if (jump) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(target,
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  // ── Typing handler ────────────────────────────────────────────────────────
  void _onTextChanged(String value) {
    if (!_isTyping && value.isNotEmpty) {
      _isTyping = true;
      _svc.setTyping(widget.chatId, true);
    }
    _typingTimer?.cancel();
    if (value.isEmpty) {
      _isTyping = false;
      _svc.setTyping(widget.chatId, false);
    } else {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _isTyping = false;
        _svc.setTyping(widget.chatId, false);
      });
    }
  }

  // ── Reply ─────────────────────────────────────────────────────────────────
  void _setReply(String messageId, String text, String senderName) {
    setState(() {
      _replyTo = {'id': messageId, 'text': text, 'senderName': senderName};
    });
    _ctrl.requestFocus();
  }

  void _clearReply() => setState(() => _replyTo = null);

  // ── Send ──────────────────────────────────────────────────────────────────
  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();

    _typingTimer?.cancel();
    _isTyping = false;
    _svc.setTyping(widget.chatId, false);

    final reply = _replyTo;
    _clearReply();

    final item = widget.itemContext;
    if (item != null && !_itemRefSent) {
      _itemRefSent = true;
      _svc.sendMessageWithItem(widget.chatId, text,
          itemData: item, replyTo: reply);
    } else {
      _svc.sendMessage(widget.chatId, text, replyTo: reply);
    }

    Future.delayed(
        const Duration(milliseconds: 150), () => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (widget.itemContext != null && !_itemCardDismissed)
            _ItemContextBanner(
              itemData: widget.itemContext!,
              onDismiss: () => setState(() => _itemCardDismissed = true),
            ),
          Expanded(child: _buildMessages()),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: BackButton(color: AppColors.primaryBlueDark),
      titleSpacing: 0,
      title: Row(
        children: [
          // FIX: Avatar in app bar also shows green dot
          StreamBuilder<bool>(
            stream: _svc.presenceStream(widget.otherUserId),
            builder: (context, presSnap) {
              final online = presSnap.data ?? false;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryBlue.withOpacity(0.85),
                          AppColors.primaryBlue.withOpacity(0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: Text(
                        widget.otherUserName.isNotEmpty
                            ? widget.otherUserName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: online
                            ? AppColors.successGreen
                            : Colors.grey.shade400,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.surface,
                          width: 2,
                        ),
                        boxShadow: online
                            ? [
                          BoxShadow(
                            color: AppColors.successGreen
                                .withOpacity(0.6),
                            blurRadius: 5,
                          )
                        ]
                            : [],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 10),
          StreamBuilder<bool>(
            stream: _svc.presenceStream(widget.otherUserId),
            builder: (context, snap) {
              final online = snap.data ?? false;
              return StreamBuilder<bool>(
                stream: _svc.isOtherTypingStream(
                    widget.chatId, widget.otherUserId),
                builder: (context, typingSnap) {
                  final isTyping = typingSnap.data ?? false;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.otherUserName,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 1),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: isTyping
                            ? Row(
                          key: const ValueKey('typing'),
                          children: [
                            Text(
                              'typing',
                              style: TextStyle(
                                color: AppColors.successGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 2),
                            _TypingDots(),
                          ],
                        )
                            : Row(
                          key: ValueKey(online),
                          children: [
                            AnimatedContainer(
                              duration:
                              const Duration(milliseconds: 400),
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: online
                                    ? AppColors.successGreen
                                    : AppColors.textSecondary
                                    .withOpacity(0.4),
                                shape: BoxShape.circle,
                                boxShadow: online
                                    ? [
                                  BoxShadow(
                                    color: AppColors.successGreen
                                        .withOpacity(0.5),
                                    blurRadius: 4,
                                  )
                                ]
                                    : [],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              online ? 'Online' : 'Offline',
                              style: TextStyle(
                                color: online
                                    ? AppColors.successGreen
                                    : AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon:
          Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: AppColors.surface,
          onSelected: _handleMenuAction,
          itemBuilder: (_) => [
            _menuItem('search', Icons.search_rounded, 'Search Messages',
                AppColors.primaryBlue),
            _menuItem('starred', Icons.star_outline_rounded,
                'Starred Messages', const Color(0xFFF59E0B)),
            _menuItem('mute', Icons.volume_off_outlined,
                'Mute Notifications', const Color(0xFF7C3AED)),
            _menuItem('archive', Icons.archive_outlined, 'Archive Chat',
                AppColors.accentOrange),
            _menuItem('clear', Icons.cleaning_services_outlined, 'Clear Chat',
                Colors.orange),
            _menuItem('delete', Icons.delete_outline_rounded, 'Delete Chat',
                Colors.red),
          ],
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.border),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color:
              value == 'delete' ? Colors.red : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'search':
        _showSearchBar();
        break;
      case 'starred':
        _showStarredMessages();
        break;
      case 'mute':
        await _svc.muteChat(widget.chatId);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(_snack('Notifications muted'));
        }
        break;
      case 'archive':
        await _svc.archiveChat(widget.chatId);
        if (mounted) Navigator.pop(context);
        break;
      case 'clear':
        final ok = await _confirmDialog(
          'Clear Chat?',
          'All messages will be cleared for you only.',
          'Clear',
          Colors.orange,
        );
        if (ok) await _svc.clearChatForMe(widget.chatId);
        break;
      case 'delete':
        final ok = await _confirmDialog(
          'Delete Chat?',
          'This chat will be hidden from your list.',
          'Delete',
          Colors.red,
        );
        if (ok) {
          await _svc.deleteChatForMe(widget.chatId);
          if (mounted) Navigator.pop(context);
        }
        break;
    }
  }

  void _showSearchBar() {
    showDialog(
      context: context,
      builder: (ctx) => _SearchDialog(chatId: widget.chatId, svc: _svc),
    );
  }

  void _showStarredMessages() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          _StarredMessagesSheet(chatId: widget.chatId, svc: _svc),
    );
  }

  Future<bool> _confirmDialog(
      String title, String body, String label, Color color) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        content: Text(body,
            style:
            TextStyle(color: AppColors.textSecondary, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Message List ──────────────────────────────────────────────────────────
  Widget _buildMessages() {
    return StreamBuilder<QuerySnapshot>(
      stream: _svc.messagesStream(widget.chatId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryBlue,
              strokeWidth: 2.5,
            ),
          );
        }

        final allDocs = snap.data?.docs ?? [];

        final msgs = allDocs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final deletedFor =
          List<String>.from(d['deletedFor'] as List? ?? []);
          if (deletedFor.contains(_svc.myId)) return false;

          if (_myClearedAt != null) {
            final ts = d['timestamp'] as Timestamp?;
            if (ts != null &&
                !ts.toDate().isAfter(_myClearedAt!.toDate())) {
              return false;
            }
          }
          return true;
        }).toList();

        if (msgs.length != _prevCount) {
          _prevCount = msgs.length;
          _svc.markMessagesRead(widget.chatId);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom(jump: msgs.length <= 1);
          });
        }

        if (msgs.isEmpty) return _buildEmptyState();

        return ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
          itemCount: msgs.length + 1,
          itemBuilder: (_, i) {
            if (i == msgs.length) {
              return StreamBuilder<bool>(
                stream: _svc.isOtherTypingStream(
                    widget.chatId, widget.otherUserId),
                builder: (ctx, snap) {
                  if (snap.data != true) return const SizedBox.shrink();
                  return _TypingBubble(name: widget.otherUserName);
                },
              );
            }

            final doc = msgs[i];
            final data = doc.data() as Map<String, dynamic>;
            final isMe = data['senderId'] == _svc.myId;
            final ts = data['timestamp'] as Timestamp?;
            final isRead = data['read'] as bool? ?? false;
            final itemRef = data['itemRef'] as Map<String, dynamic>?;
            final replyTo = data['replyTo'] as Map<String, dynamic>?;
            final deletedForEveryone =
                data['deletedForEveryone'] as bool? ?? false;
            final reactions = Map<String, dynamic>.from(
                data['reactions'] as Map? ?? {});
            final starredBy =
            List<String>.from(data['starredBy'] as List? ?? []);
            final isStarred = starredBy.contains(_svc.myId);

            final time = ts != null
                ? '${ts.toDate().hour.toString().padLeft(2, '0')}:'
                '${ts.toDate().minute.toString().padLeft(2, '0')}'
                : '';

            final showDate = i == 0 ||
                _isDifferentDay(
                  (msgs[i - 1].data() as Map)['timestamp'] as Timestamp?,
                  ts,
                );

            return Column(
              children: [
                if (showDate && ts != null)
                  _DateSeparator(date: ts.toDate()),
                GestureDetector(
                  onLongPress: deletedForEveryone
                      ? null
                      : () {
                    HapticFeedback.mediumImpact();
                    _showMessageOptions(
                      context,
                      doc.id,
                      data['text'] as String? ?? '',
                      isMe: isMe,
                      senderName:
                      isMe ? 'You' : widget.otherUserName,
                      reactions: reactions,
                      isStarred: isStarred,
                    );
                  },
                  child: Dismissible(
                    key: Key('msg_${doc.id}'),
                    direction: DismissDirection.startToEnd,
                    confirmDismiss: (_) async {
                      if (!deletedForEveryone) {
                        _setReply(
                          doc.id,
                          data['text'] as String? ?? '',
                          isMe ? 'You' : widget.otherUserName,
                        );
                      }
                      return false;
                    },
                    background: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                            AppColors.primaryBlue.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.reply_rounded,
                              color: AppColors.primaryBlue, size: 20),
                        ),
                      ),
                    ),
                    // FIX: Pass otherUserId to bubble for live tick logic
                    child: _MessageBubble(
                      messageId: doc.id,
                      text: data['text'] as String? ?? '',
                      time: time,
                      isMe: isMe,
                      isRead: isRead,
                      otherUserId: widget.otherUserId,
                      chatService: _svc,
                      itemRef: itemRef,
                      replyTo: replyTo,
                      reactions: reactions,
                      isStarred: isStarred,
                      myId: _svc.myId,
                      deletedForEveryone: deletedForEveryone,
                      onReactionTap: (emoji) =>
                          _svc.toggleReaction(widget.chatId, doc.id, emoji),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMessageOptions(
      BuildContext context,
      String messageId,
      String text, {
        required bool isMe,
        required String senderName,
        required Map<String, dynamic> reactions,
        required bool isStarred,
      }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MessageOptionsSheet(
        text: text,
        isMe: isMe,
        reactions: reactions,
        myId: _svc.myId,
        isStarred: isStarred,
        onReact: (emoji) {
          Navigator.pop(ctx);
          _svc.toggleReaction(widget.chatId, messageId, emoji);
        },
        onReply: () {
          Navigator.pop(ctx);
          _setReply(messageId, text, senderName);
        },
        onCopy: () {
          Navigator.pop(ctx);
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context)
              .showSnackBar(_snack('Message copied'));
        },
        onStar: () {
          Navigator.pop(ctx);
          _svc.toggleStarMessage(widget.chatId, messageId);
          ScaffoldMessenger.of(context).showSnackBar(_snack(
              isStarred ? 'Unstarred message' : 'Message starred ⭐'));
        },
        onForward: () {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context)
              .showSnackBar(_snack('Forward coming soon'));
        },
        onDeleteForMe: () {
          Navigator.pop(ctx);
          _svc.deleteMessageForMe(widget.chatId, messageId);
        },
        onDeleteForEveryone: isMe
            ? () {
          Navigator.pop(ctx);
          _svc.deleteMessageForEveryone(widget.chatId, messageId);
        }
            : null,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.waving_hand_rounded,
              size: 34,
              color: AppColors.primaryBlue.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Say hello to ${widget.otherUserName}!',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.itemContext != null) ...[
            const SizedBox(height: 8),
            Text(
              'Ask about "${widget.itemContext!['title'] ?? 'this item'}"',
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isDifferentDay(Timestamp? a, Timestamp? b) {
    if (a == null || b == null) return false;
    final da = a.toDate(), db = b.toDate();
    return da.year != db.year ||
        da.month != db.month ||
        da.day != db.day;
  }

  // ── Input Bar ─────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyTo != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(
                    color: AppColors.primaryBlue,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _replyTo!['senderName'] as String? ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (_replyTo!['text'] as String? ?? '').length > 60
                              ? '${(_replyTo!['text'] as String).substring(0, 60)}…'
                              : _replyTo!['text'] as String? ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearReply,
                    child: Icon(Icons.close_rounded,
                        size: 18, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

          Padding(
            padding: EdgeInsets.fromLTRB(
                12,
                10,
                12,
                MediaQuery.of(context).padding.bottom + 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.attach_file_rounded,
                      color: AppColors.primaryBlue, size: 20),
                ),
                const SizedBox(width: 8),

                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: _onTextChanged,
                    onSubmitted: (_) => _send(),
                    maxLines: 4,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: widget.itemContext != null && !_itemRefSent
                          ? 'Ask about this item…'
                          : 'Type a message…',
                      hintStyle:
                      TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                GestureDetector(
                  onTap: _send,
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.primaryBlue,
                          AppColors.accentOrange
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                          AppColors.primaryBlue.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  SnackBar _snack(String msg) => SnackBar(
    content:
    Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
    behavior: SnackBarBehavior.floating,
    backgroundColor: AppColors.primaryBlueDark,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 2),
  );
}

extension on TextEditingController {
  void requestFocus() {}
}

// ─── Typing dots animation ────────────────────────────────────────────────────
class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
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
          children: List.generate(3, (i) {
            final delay = i / 3;
            final value = ((_ctrl.value - delay + 1) % 1.0);
            final opacity = value < 0.5 ? value * 2 : (1 - value) * 2;
            return Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Container(
                width: 4,
                height: 4,
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

// ─── Typing bubble ────────────────────────────────────────────────────────────
class _TypingBubble extends StatelessWidget {
  final String name;
  const _TypingBubble({required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$name is typing',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 6),
                _TypingDots(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Message options sheet ────────────────────────────────────────────────────
class _MessageOptionsSheet extends StatelessWidget {
  final String text;
  final bool isMe;
  final Map<String, dynamic> reactions;
  final String myId;
  final bool isStarred;
  final void Function(String emoji) onReact;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onStar;
  final VoidCallback onForward;
  final VoidCallback onDeleteForMe;
  final VoidCallback? onDeleteForEveryone;

  const _MessageOptionsSheet({
    required this.text,
    required this.isMe,
    required this.reactions,
    required this.myId,
    required this.isStarred,
    required this.onReact,
    required this.onReply,
    required this.onCopy,
    required this.onStar,
    required this.onForward,
    required this.onDeleteForMe,
    this.onDeleteForEveryone,
  });

  static const _quickEmojis = ['❤️', '👍', '😂', '😮', '😢', '🙏'];

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
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ..._quickEmojis.map((emoji) {
                  final myReacted =
                  (reactions[emoji] as List? ?? []).contains(myId);
                  return GestureDetector(
                    onTap: () => onReact(emoji),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: myReacted
                            ? AppColors.primaryBlue.withOpacity(0.15)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(emoji,
                          style:
                          TextStyle(fontSize: myReacted ? 26 : 24)),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () => onReact('👏'),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.border.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add_rounded,
                        size: 18, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border:
              Border.all(color: AppColors.border.withOpacity(0.5)),
            ),
            child: Text(
              text.length > 80 ? '${text.substring(0, 80)}…' : text,
              style:
              TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: AppColors.border),
          _SheetOption(
            icon: Icons.reply_rounded,
            label: 'Reply',
            color: AppColors.primaryBlue,
            onTap: onReply,
          ),
          _SheetOption(
            icon: Icons.copy_rounded,
            label: 'Copy Text',
            color: const Color(0xFF059669),
            onTap: onCopy,
          ),
          _SheetOption(
            icon: Icons.forward_rounded,
            label: 'Forward',
            color: const Color(0xFF7C3AED),
            onTap: onForward,
          ),
          _SheetOption(
            icon: isStarred
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            label: isStarred ? 'Unstar Message' : 'Star Message',
            color: const Color(0xFFF59E0B),
            onTap: onStar,
          ),
          _SheetOption(
            icon: Icons.delete_outline_rounded,
            label: 'Delete for Me',
            color: AppColors.accentOrange,
            onTap: onDeleteForMe,
          ),
          if (onDeleteForEveryone != null)
            _SheetOption(
              icon: Icons.delete_sweep_outlined,
              label: 'Delete for Everyone',
              color: Colors.red,
              onTap: onDeleteForEveryone!,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Cancel',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SheetOption({
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
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: label.contains('Everyone')
              ? Colors.red
              : AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ── Starred Messages Sheet ────────────────────────────────────────────────────
class _StarredMessagesSheet extends StatelessWidget {
  final String chatId;
  final ChatService svc;

  const _StarredMessagesSheet({required this.chatId, required this.svc});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
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
              child: Row(
                children: [
                  Icon(Icons.star_rounded,
                      color: const Color(0xFFF59E0B), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Starred Messages',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: AppColors.border),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: svc.messagesStream(chatId),
                builder: (ctx, snap) {
                  final docs = (snap.data?.docs ?? []).where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final starred = List<String>.from(
                        data['starredBy'] as List? ?? []);
                    return starred.contains(svc.myId);
                  }).toList();

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_border_rounded,
                              size: 48,
                              color: AppColors.textSecondary
                                  .withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text('No starred messages',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                              )),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: ctrl,
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      final ts = d['timestamp'] as Timestamp?;
                      return ListTile(
                        leading: Icon(Icons.star_rounded,
                            color: const Color(0xFFF59E0B), size: 18),
                        title: Text(
                          d['text'] as String? ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: ts != null
                            ? Text(
                            '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ))
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search Dialog ─────────────────────────────────────────────────────────────
class _SearchDialog extends StatefulWidget {
  final String chatId;
  final ChatService svc;

  const _SearchDialog({required this.chatId, required this.svc});

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Search Messages',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: (v) =>
                  setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search…',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                prefixIcon: Icon(Icons.search_rounded,
                    color: AppColors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_query.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 280,
                child: StreamBuilder<QuerySnapshot>(
                  stream: widget.svc.messagesStream(widget.chatId),
                  builder: (ctx, snap) {
                    final docs = snap.data?.docs ?? [];
                    final results = docs.where((d) {
                      final text =
                          (d.data() as Map<String, dynamic>)['text']
                          as String? ??
                              '';
                      return text.toLowerCase().contains(_query);
                    }).toList();

                    if (results.isEmpty) {
                      return Center(
                        child: Text('No results',
                            style: TextStyle(
                                color: AppColors.textSecondary)),
                      );
                    }
                    return ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final d =
                        results[i].data() as Map<String, dynamic>;
                        final text = d['text'] as String? ?? '';
                        final ts = d['timestamp'] as Timestamp?;
                        return ListTile(
                          dense: true,
                          title: Text(text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: ts != null
                              ? Text(
                              '${ts.toDate().day}/${ts.toDate().month}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ))
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Item Context Banner ───────────────────────────────────────────────────────
class _ItemContextBanner extends StatelessWidget {
  final Map<String, dynamic> itemData;
  final VoidCallback onDismiss;

  const _ItemContextBanner({
    required this.itemData,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isRent = (itemData['listingType'] ?? 'sell') == 'rent';
    final color = isRent ? AppColors.accentOrange : AppColors.primaryBlue;
    final imageUrl = itemData['image'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(13),
              bottomLeft: Radius.circular(13),
            ),
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _imgPlaceholder(color))
                : _imgPlaceholder(color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isRent ? 'FOR RENT' : 'FOR SALE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  itemData['title'] ?? 'Item',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (itemData['price'] != null)
                  Text(
                    'Rs. ${itemData['price']}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                size: 18, color: AppColors.textSecondary),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder(Color color) => Container(
    width: 60,
    height: 60,
    color: color.withOpacity(0.1),
    child: Icon(Icons.image_outlined,
        size: 24, color: color.withOpacity(0.4)),
  );
}

// ── Message Bubble — FIX: live read receipts via StreamBuilder ────────────────
class _MessageBubble extends StatelessWidget {
  final String messageId;
  final String text;
  final String time;
  final bool isMe;
  final bool isRead;
  final String otherUserId;          // NEW: needed for presence check
  final ChatService chatService;     // NEW: needed for presence stream
  final Map<String, dynamic>? itemRef;
  final Map<String, dynamic>? replyTo;
  final Map<String, dynamic> reactions;
  final bool isStarred;
  final String myId;
  final bool deletedForEveryone;
  final void Function(String emoji) onReactionTap;

  const _MessageBubble({
    required this.messageId,
    required this.text,
    required this.time,
    required this.isMe,
    required this.isRead,
    required this.otherUserId,
    required this.chatService,
    required this.reactions,
    required this.isStarred,
    required this.myId,
    required this.onReactionTap,
    this.itemRef,
    this.replyTo,
    this.deletedForEveryone = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72),
            decoration: BoxDecoration(
              color: isMe ? AppColors.primaryBlue : AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
              border:
              isMe ? null : Border.all(color: AppColors.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (itemRef != null && !deletedForEveryone)
                  _ItemRefCard(itemRef: itemRef!, isMe: isMe),

                if (replyTo != null && !deletedForEveryone)
                  _ReplyPreviewInBubble(replyTo: replyTo!, isMe: isMe),

                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      deletedForEveryone
                          ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.block_rounded,
                              size: 14,
                              color: isMe
                                  ? Colors.white54
                                  : AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'This message was deleted',
                            style: TextStyle(
                              color: isMe
                                  ? Colors.white54
                                  : AppColors.textSecondary,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      )
                          : Text(
                        text,
                        style: TextStyle(
                          color:
                          isMe ? Colors.white : AppColors.textPrimary,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isStarred) ...[
                            Icon(Icons.star_rounded,
                                size: 11,
                                color: isMe
                                    ? Colors.white60
                                    : const Color(0xFFF59E0B)),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe
                                  ? Colors.white60
                                  : AppColors.textSecondary,
                            ),
                          ),
                          // FIX: Smart tick — uses live presence stream
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            StreamBuilder<bool>(
                              stream:
                              chatService.presenceStream(otherUserId),
                              builder: (context, presSnap) {
                                final isOnline = presSnap.data ?? false;
                                return _TickIcon(
                                  isRead: isRead,
                                  isOnline: isOnline,
                                );
                              },
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

          if (reactions.isNotEmpty && !deletedForEveryone)
            _ReactionsRow(
              reactions: reactions,
              myId: myId,
              isMe: isMe,
              onTap: onReactionTap,
            ),
        ],
      ),
    );
  }
}

/// FIX: Three-state tick widget
/// - Offline + unread  → single grey tick  (sent, not delivered)
/// - Online  + unread  → double grey tick  (delivered, not read)
/// - Read              → double blue tick  (read)
class _TickIcon extends StatelessWidget {
  final bool isRead;
  final bool isOnline;

  const _TickIcon({required this.isRead, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    if (isRead) {
      // Blue double tick
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Icon(
          Icons.done_all_rounded,
          key: const ValueKey('read'),
          size: 14,
          color: Colors.lightBlueAccent.withOpacity(0.95),
        ),
      );
    } else if (isOnline) {
      // Grey double tick (delivered but not read)
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Icon(
          Icons.done_all_rounded,
          key: const ValueKey('delivered'),
          size: 14,
          color: Colors.white60,
        ),
      );
    } else {
      // Single grey tick (sent, recipient offline)
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Icon(
          Icons.done_rounded,
          key: const ValueKey('sent'),
          size: 14,
          color: Colors.white60,
        ),
      );
    }
  }
}

// ── Reply preview inside bubble ───────────────────────────────────────────────
class _ReplyPreviewInBubble extends StatelessWidget {
  final Map<String, dynamic> replyTo;
  final bool isMe;

  const _ReplyPreviewInBubble({
    required this.replyTo,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final senderName = replyTo['senderName'] as String? ?? '';
    final text = replyTo['text'] as String? ?? '';

    final bgColor = isMe
        ? Colors.white.withOpacity(0.12)
        : AppColors.primaryBlue.withOpacity(0.06);
    final barColor =
    isMe ? Colors.white.withOpacity(0.6) : AppColors.primaryBlue;
    final nameColor = isMe ? Colors.white70 : AppColors.primaryBlue;
    final textColor = isMe ? Colors.white60 : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: barColor, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: nameColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text.length > 60 ? '${text.substring(0, 60)}…' : text,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Reactions row ─────────────────────────────────────────────────────────────
class _ReactionsRow extends StatelessWidget {
  final Map<String, dynamic> reactions;
  final String myId;
  final bool isMe;
  final void Function(String emoji) onTap;

  const _ReactionsRow({
    required this.reactions,
    required this.myId,
    required this.isMe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final entries = reactions.entries
        .where((e) => (e.value as List).isNotEmpty)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: 6,
        left: isMe ? 0 : 4,
        right: isMe ? 4 : 0,
      ),
      child: Wrap(
        spacing: 4,
        children: entries.map((e) {
          final emoji = e.key;
          final users = List<String>.from(e.value as List);
          final count = users.length;
          final myReacted = users.contains(myId);

          return GestureDetector(
            onTap: () => onTap(emoji),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: myReacted
                    ? AppColors.primaryBlue.withOpacity(0.15)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: myReacted
                      ? AppColors.primaryBlue.withOpacity(0.4)
                      : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji,
                      style: const TextStyle(fontSize: 13)),
                  if (count > 1) ...[
                    const SizedBox(width: 3),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: myReacted
                            ? AppColors.primaryBlue
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Item Reference Card ───────────────────────────────────────────────────────
class _ItemRefCard extends StatelessWidget {
  final Map<String, dynamic> itemRef;
  final bool isMe;

  const _ItemRefCard({required this.itemRef, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final imageUrl = itemRef['image'] as String? ?? '';
    final isRent = (itemRef['listingType'] ?? 'sell') == 'rent';
    final divider =
    isMe ? Colors.white.withOpacity(0.15) : AppColors.border;

    return Container(
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.12) : AppColors.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(17),
          topRight: Radius.circular(17),
        ),
        border: Border(bottom: BorderSide(color: divider, width: 1)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius:
            const BorderRadius.only(topLeft: Radius.circular(17)),
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _ph(isMe, isRent))
                : _ph(isMe, isRent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding:
              const EdgeInsets.only(right: 10, top: 8, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRent ? '🔑 For Rent' : '🏷️ For Sale',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isMe
                          ? Colors.white70
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    itemRef['title'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isMe ? Colors.white : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((itemRef['price'] ?? '').toString().isNotEmpty)
                    Text(
                      'Rs. ${itemRef['price']}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isMe
                            ? Colors.white70
                            : AppColors.accentOrange,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ph(bool isMe, bool isRent) => Container(
    width: 56,
    height: 56,
    color: isMe
        ? Colors.white.withOpacity(0.1)
        : AppColors.primaryBlueLight,
    child: Icon(
      isRent ? Icons.key_outlined : Icons.sell_outlined,
      size: 22,
      color: isMe
          ? Colors.white38
          : AppColors.primaryBlue.withOpacity(0.4),
    ),
  );
}

// ── Date Separator ────────────────────────────────────────────────────────────
class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    final label = diff == 0
        ? 'Today'
        : diff == 1
        ? 'Yesterday'
        : '${date.day} ${_month(date.month)} ${date.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.border)),
          const SizedBox(width: 10),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }

  String _month(int m) => const [
    '',
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ][m];
}