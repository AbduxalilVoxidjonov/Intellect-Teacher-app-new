import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/teacher_api.dart';
import '../../models/models.dart';
import '../../services/session.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';

/// O'qituvchi ilovasi xodimlar kanali kaliti — web `STAFF_CHANNEL` bilan bir xil
/// ("@/config/constants" `STAFF_CHANNEL` = '__xodimlar__').
const String _kStaffChannel = '__xodimlar__';
const String _kStaffChannelLabel = 'Xodimlar';

/// Xabarlar (TAB) — kanallar ro'yxati (xodimlar + o'z guruhlari), bosilsa
/// shu tab ichida to'liq suhbat (xabarlar + composer, 4s polling).
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => MessagesScreenState();
}

/// DIQQAT: holat sinfi ATAYLAB ochiq (public) — qobiq (`ShellScreen`) qurilmaning
/// "orqaga" tugmasini shu tabga uzatadi: suhbat ochiq bo'lsa avval u yopiladi
/// (ilova yopilib ketmasin).
class MessagesScreenState extends State<MessagesScreen> {
  bool _loading = true;
  List<String> _classes = [];
  String? _selected;

  /// Tab ichida ochiq suhbat bormi (qobiq "orqaga" mantiqi uchun).
  bool get hasOpenChat => _selected != null;

  /// Ochiq suhbatni yopadi. `true` — "orqaga" shu yerda ishlatildi.
  bool handleBack() {
    if (_selected == null) return false;
    setState(() => _selected = null);
    return true;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cs = await TeacherApi.chatClasses();
      if (mounted) {
        setState(() => _classes = cs.where((c) => c != _kStaffChannel).toList());
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      final isStaff = _selected == _kStaffChannel;
      return _ChatView(
        className: _selected!,
        title: isStaff ? _kStaffChannelLabel : '${_selected!} — guruh chati',
        subtitle: isStaff ? "Barcha o'qituvchilar va adminlar" : 'Guruh chati',
        onBack: () => setState(() => _selected = null),
      );
    }

    final c = AppTheme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Xabarlar',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.text, letterSpacing: -0.3)),
              const SizedBox(height: 2),
              Text('Guruh va xodimlar chati', style: TextStyle(fontSize: 12, color: c.muted)),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Loader(label: 'Yuklanmoqda...')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    _ChannelRow(
                      icon: Icons.work_outline_rounded,
                      name: _kStaffChannelLabel,
                      hint: "Barcha o'qituvchilar va adminlar",
                      staff: true,
                      onTap: () => setState(() => _selected = _kStaffChannel),
                    ),
                    const SizedBox(height: 8),
                    for (final cl in _classes) ...[
                      _ChannelRow(
                        icon: Icons.chat_bubble_outline_rounded,
                        name: cl,
                        hint: 'Guruh chati',
                        onTap: () => setState(() => _selected = cl),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_classes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: EmptyState(icon: Icons.groups_outlined, text: "Sizga biriktirilgan guruh yo'q."),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ChannelRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final String hint;
  final bool staff;
  final VoidCallback onTap;
  const _ChannelRow({
    required this.icon,
    required this.name,
    required this.hint,
    this.staff = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: staff ? [const Color(0xFF8B5CF6), const Color(0xFFC026D3)] : [c.accent, c.accentD],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.faint)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.faint),
        ],
      ),
    );
  }
}

/// Bitta kanalning to'liq-ekran suhbati (tab ichida, orqaga tugma bilan).
class _ChatView extends StatefulWidget {
  final String className;
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  const _ChatView({
    required this.className,
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  bool _loading = true;
  List<ChatMessage> _messages = [];
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _timer;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    try {
      final since = _messages.isEmpty ? null : _messages.last.createdAt;
      final fetched = await TeacherApi.chat(widget.className, since: since);
      if (!mounted) return;
      if (since == null) {
        setState(() => _messages = fetched);
        _scrollToBottom();
      } else if (fetched.isNotEmpty) {
        setState(() => _messages = [..._messages, ...fetched]);
        _scrollToBottom();
      }
    } catch (_) {
    } finally {
      if (initial && mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final msg = await TeacherApi.sendChat(widget.className, text);
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, msg];
        _controller.clear();
      });
      _scrollToBottom();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final myId = context.read<Session>().teacherId;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.border))),
          child: Row(
            children: [
              InkWell(
                onTap: widget.onBack,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: c.text),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: c.text)),
                    Text(widget.subtitle, style: TextStyle(fontSize: 11, color: c.faint)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Loader(label: 'Yuklanmoqda...')
              : _messages.isEmpty
                  ? const Center(child: EmptyState(icon: Icons.chat_bubble_outline_rounded, text: "Hali xabar yo'q."))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        return _Bubble(msg: m, isMe: myId != null && m.senderUserId == myId);
                      },
                    ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Xabar yozing...',
                      filled: true,
                      fillColor: c.surface2,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: c.accent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _sending ? null : _send,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isMe;
  const _Bubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: isMe ? c.accent : c.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(msg.senderName,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: c.accentD)),
              ),
            Text(msg.text, style: TextStyle(fontSize: 14, color: isMe ? Colors.white : c.text, height: 1.3)),
            const SizedBox(height: 3),
            Text(fmtTime(msg.createdAt),
                style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : c.faint)),
          ],
        ),
      ),
    );
  }
}
