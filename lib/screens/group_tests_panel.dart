import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/teacher_api.dart';
import '../config.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';

/// Guruh testlari (imtihonlari) paneli — web `TeacherGroupTestsPanel.tsx` bilan bir xil.
/// Ikki joyda AYNAN bir xil ishlaydi:
///  • pastki navigatsiyadagi «Testlar» bo'limi (guruh tanlangandan keyin);
///  • guruh (jurnal) sahifasidagi «Imtihonlar» tabi.
///
/// Ikki rejim (serverda bitta `TestResultService`):
///  • OFLAYN — nom, sana, maksimal ball; ballni o'qituvchi qo'lda kiritadi.
///  • ONLAYN (bot) — savollar fayli (PDF/rasm), savollar soni, variantlar, javoblar kaliti va
///    vaqt oynasi; o'quvchi Telegram botdan ishlaydi, ball avtomatik yoziladi (har savol 1 ball).
///
/// DIQQAT: panel o'zi scroll QILMAYDI (Column qaytaradi) — tashqi sahifa scroll qiladi.
class GroupTestsPanel extends StatefulWidget {
  final String groupId;

  /// Ro'yxat tepasidagi sarlavha (bo'sh bo'lsa sarlavha chiqmaydi).
  final String title;
  final String? subtitle;
  const GroupTestsPanel({
    super.key,
    required this.groupId,
    this.title = '',
    this.subtitle,
  });

  @override
  State<GroupTestsPanel> createState() => _GroupTestsPanelState();
}

class _GroupTestsPanelState extends State<GroupTestsPanel> {
  bool _loading = true;
  String? _error;
  List<GroupTest> _tests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tests = await TeacherApi.groupTests(widget.groupId);
      if (!mounted) return;
      setState(() {
        _tests = tests;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openForm({GroupTest? editing}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TestFormSheet(groupId: widget.groupId, editing: editing),
    );
    if (ok == true) _load();
  }

  Future<void> _openDetail(GroupTest t) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TestDetailScreen(testId: t.id, title: t.name)),
    );
    if (mounted) _load();
  }

  Future<void> _delete(GroupTest t) async {
    final c = AppTheme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Testni o'chirish"),
        content: Text('"${t.name}" testi va unga kiritilgan barcha ballar o\'chiriladi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor qilish')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("O'chirish", style: TextStyle(color: c.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await TeacherApi.deleteTest(t.id);
      if (!mounted) return;
      setState(() => _tests.removeWhere((x) => x.id == t.id));
    } catch (e) {
      _toast(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (widget.title.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
                    if (widget.subtitle != null)
                      Text(widget.subtitle!,
                          style: TextStyle(fontSize: 12, color: c.muted)),
                  ],
                ),
              )
            else
              const Spacer(),
            Material(
              color: c.accent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openForm(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Yangi test',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Loader())
        else if (_error != null)
          EmptyState(icon: Icons.error_outline_rounded, text: _error!)
        else if (_tests.isEmpty)
          const EmptyState(
            icon: Icons.assignment_outlined,
            text: "Hali test yaratilmagan.\n\"Yangi test\" tugmasi orqali qo'shing.",
          )
        else
          for (final t in _tests) ...[
            _testCard(c, t),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _testCard(AppColors c, GroupTest t) {
    final online = t.online.isOnline;
    return SCard(
      padding: const EdgeInsets.all(14),
      onTap: () => _openDetail(t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: online ? const Color(0x1A7C3AED) : c.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  online ? Icons.smart_toy_rounded : Icons.assignment_turned_in_outlined,
                  color: online ? const Color(0xFF7C3AED) : c.accent,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(t.name,
                              maxLines: 2,
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.text)),
                        ),
                        if (online) ...[
                          const SizedBox(width: 6),
                          const SChip('ONLAYN', color: Color(0xFF7C3AED), bg: Color(0x147C3AED)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      online
                          ? '${fmtDate(t.date)} · botdan yuborgan: ${t.submittedCount}/${t.studentCount}'
                          : fmtDate(t.date),
                      style: TextStyle(fontSize: 11.5, color: c.muted),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: c.faint),
                onSelected: (v) {
                  if (v == 'edit') _openForm(editing: t);
                  if (v == 'delete') _delete(t);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Tahrirlash')),
                  PopupMenuItem(value: 'delete', child: Text("O'chirish")),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(12)),
            child: Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                Text('${t.scoredCount}/${t.studentCount} baholangan',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.text)),
                if (t.avgScore != null)
                  Text("O'rtacha: ${t.avgScore!.toStringAsFixed(1)}",
                      style: TextStyle(fontSize: 11.5, color: c.muted)),
                Text('Maks: ${_num(t.maxScore)}', style: TextStyle(fontSize: 11.5, color: c.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================ Test tafsiloti ============================ */

/// Test tafsiloti — o'quvchilar ballari (ball desc) + onlayn test ma'lumoti.
/// Ball kiritilganda ro'yxat serverdan qayta saralangan holda keladi.
class TestDetailScreen extends StatefulWidget {
  final String testId;
  final String title;
  const TestDetailScreen({super.key, required this.testId, required this.title});

  @override
  State<TestDetailScreen> createState() => _TestDetailScreenState();
}

class _TestDetailScreenState extends State<TestDetailScreen> {
  TestResultDetail? _detail;
  bool _loading = true;
  String? _error;
  String? _savingId;
  bool _showKey = false;

  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, FocusNode> _nodes = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  String _fmtScore(double? s) => s == null ? '' : _num(s);

  void _syncControllers(TestResultDetail d) {
    for (final r in d.rows) {
      final ctrl = _ctrls.putIfAbsent(r.studentId, () => TextEditingController());
      final node = _nodes.putIfAbsent(r.studentId, () {
        final n = FocusNode();
        // Fokus yo'qolganda saqlanadi (web `onBlur` bilan bir xil).
        n.addListener(() {
          if (!n.hasFocus) _save(r.studentId);
        });
        return n;
      });
      if (!node.hasFocus) ctrl.text = _fmtScore(r.score);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await TeacherApi.testDetail(widget.testId);
      if (!mounted) return;
      _syncControllers(d);
      setState(() {
        _detail = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save(String studentId) async {
    final d = _detail;
    if (d == null || _savingId != null) return;
    final raw = (_ctrls[studentId]?.text ?? '').trim().replaceAll(',', '.');
    final current = d.rows.firstWhere((r) => r.studentId == studentId).score;
    final next = raw.isEmpty ? null : double.tryParse(raw);
    if (raw.isNotEmpty && (next == null || next < 0 || next > d.maxScore)) {
      // Noto'g'ri qiymat — eski holatga qaytaramiz.
      _ctrls[studentId]?.text = _fmtScore(current);
      if (mounted && next != null && next > d.maxScore) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ball 0 dan ${_num(d.maxScore)} gacha bo'lishi kerak")),
        );
      }
      return;
    }
    if (next == current) return; // o'zgarmagan
    setState(() => _savingId = studentId);
    try {
      final updated = await TeacherApi.setTestScore(widget.testId, studentId, next);
      if (!mounted) return;
      _syncControllers(updated);
      setState(() => _detail = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      _ctrls[studentId]?.text = _fmtScore(current);
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final d = _detail;
    return SubScaffold(
      title: widget.title,
      child: _loading
          ? const Center(child: Loader())
          : d == null
              ? EmptyState(icon: Icons.error_outline_rounded, text: _error ?? 'Test topilmadi')
              : RefreshIndicator(
                  color: c.accent,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event_rounded, size: 15, color: c.muted),
                          const SizedBox(width: 5),
                          Text(fmtDate(d.date), style: TextStyle(fontSize: 12.5, color: c.muted)),
                          const SizedBox(width: 12),
                          Icon(Icons.star_outline_rounded, size: 15, color: c.muted),
                          const SizedBox(width: 5),
                          Text('Maks ${_num(d.maxScore)}', style: TextStyle(fontSize: 12.5, color: c.muted)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (d.online.isOnline) ...[
                        _onlineCard(c, d),
                        const SizedBox(height: 10),
                      ],
                      if (d.rows.isEmpty)
                        const EmptyState(icon: Icons.people_outline, text: "Guruhda faol o'quvchi yo'q.")
                      else
                        for (final r in d.rows) ...[
                          _row(c, d, r),
                          const SizedBox(height: 8),
                        ],
                    ],
                  ),
                ),
    );
  }

  Widget _onlineCard(AppColors c, TestResultDetail d) {
    const violet = Color(0xFF7C3AED);
    final o = d.online;
    final lastLetter = _letters[(o.optionCount.clamp(2, 6)) - 1];
    return SCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SChip('ONLAYN TEST', color: violet, bg: Color(0x147C3AED)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Savollar: ${o.questionCount} ta (A–$lastLetter)',
                    style: TextStyle(fontSize: 12, color: c.muted)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 15, color: c.faint),
              const SizedBox(width: 5),
              Text('${_timeOf(o.startAt, '—')}–${_timeOf(o.endAt, '—')}',
                  style: TextStyle(fontSize: 12, color: c.muted)),
              const SizedBox(width: 14),
              Icon(Icons.send_rounded, size: 15, color: c.faint),
              const SizedBox(width: 5),
              Text('Botdan yuborgan: ${d.submittedCount}',
                  style: TextStyle(fontSize: 12, color: c.muted)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (o.pdfUrl.isNotEmpty)
                GestureDetector(
                  onTap: () => _openFile(o.pdfUrl),
                  child: Row(
                    children: [
                      Icon(Icons.description_outlined, size: 16, color: c.accent),
                      const SizedBox(width: 4),
                      Text(o.pdfName.isEmpty ? 'Savollar fayli' : o.pdfName,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.accent)),
                    ],
                  ),
                ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showKey = !_showKey),
                child: Row(
                  children: [
                    Icon(_showKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 16, color: c.muted),
                    const SizedBox(width: 4),
                    Text('Javob kaliti',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.muted)),
                  ],
                ),
              ),
            ],
          ),
          if (_showKey) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(10)),
              child: Text(
                [
                  for (var i = 0; i < o.answerKey.length; i++) '${i + 1}.${o.answerKey[i]}',
                ].join('   '),
                style: TextStyle(fontSize: 11.5, height: 1.7, color: c.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openFile(String url) async {
    final full = url.startsWith('http') ? url : '$kFileBaseUrl$url';
    try {
      await launchUrl(Uri.parse(full), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Faylni ochib bo'lmadi")));
      }
    }
  }

  Widget _row(AppColors c, TestResultDetail d, TestScoreRow r) {
    const medals = ['🥇', '🥈', '🥉'];
    final isTop = r.rank >= 1 && r.rank <= 3;
    final online = d.online.isOnline;
    return SCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Center(
              child: r.rank == 0
                  ? Text('—', style: TextStyle(color: c.faint))
                  : isTop
                      ? Text(medals[r.rank - 1], style: const TextStyle(fontSize: 18))
                      : Text('${r.rank}',
                          style: TextStyle(fontWeight: FontWeight.w800, color: c.muted, fontSize: 15)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: isTop ? FontWeight.w800 : FontWeight.w600,
                        color: c.text)),
                if (online)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: r.fromBot
                        ? Text('${r.answers} · ${_timeOf(r.submittedAt, '—')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10.5, color: c.faint))
                        : Text('— topshirmagan', style: TextStyle(fontSize: 10.5, color: c.faint)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_savingId == r.studentId)
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: c.accent)),
          const SizedBox(width: 6),
          SizedBox(
            width: 64,
            child: TextField(
              controller: _ctrls[r.studentId],
              focusNode: _nodes[r.studentId],
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(r.studentId),
              style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                isDense: true,
                hintText: '—',
                hintStyle: TextStyle(color: c.faint),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                filled: true,
                fillColor: c.surface2,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: c.accent, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text('/${_num(d.maxScore)}', style: TextStyle(fontSize: 11, color: c.faint)),
        ],
      ),
    );
  }
}

/* ============================ Test yaratish/tahrirlash ============================ */

/// Test formasi — OFLAYN yoki ONLAYN (bot). Web `TeacherTestFormModal` bilan bir xil maydonlar.
class TestFormSheet extends StatefulWidget {
  final String groupId;
  final GroupTest? editing;
  const TestFormSheet({super.key, required this.groupId, this.editing});

  @override
  State<TestFormSheet> createState() => _TestFormSheetState();
}

class _TestFormSheetState extends State<TestFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _maxScore;
  late final TextEditingController _count;
  final TextEditingController _bulkKey = TextEditingController();

  late DateTime _date;
  bool _online = false;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  // Onlayn maydonlari.
  String _pdfUrl = '';
  String _pdfName = '';
  int _options = 4;
  List<String> _key = [];
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 11, minute: 0);

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    final o = e?.online ?? const OnlineTest();
    _online = o.isOnline;
    _name = TextEditingController(text: e?.name ?? '');
    _maxScore = TextEditingController(text: e == null ? '100' : _num(e.maxScore));
    _count = TextEditingController(text: o.questionCount > 0 ? '${o.questionCount}' : '20');
    _date = e != null ? (DateTime.tryParse(e.date) ?? DateTime.now()) : DateTime.now();
    _pdfUrl = o.pdfUrl;
    _pdfName = o.pdfName;
    _options = o.optionCount < 2 ? 4 : o.optionCount;
    _key = o.answerKey.split('').map((ch) => ch == '-' ? '' : ch).toList();
    _start = _parseTime(o.startAt, const TimeOfDay(hour: 9, minute: 0));
    _end = _parseTime(o.endAt, const TimeOfDay(hour: 11, minute: 0));
  }

  @override
  void dispose() {
    _name.dispose();
    _maxScore.dispose();
    _count.dispose();
    _bulkKey.dispose();
    super.dispose();
  }

  static TimeOfDay _parseTime(String iso, TimeOfDay fallback) {
    if (iso.length < 16) return fallback;
    final h = int.tryParse(iso.substring(11, 13));
    final m = int.tryParse(iso.substring(14, 16));
    if (h == null || m == null) return fallback;
    return TimeOfDay(hour: h, minute: m);
  }

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Savollar soni (1..200).
  int get _qCount {
    final n = int.tryParse(_count.text.trim()) ?? 0;
    if (n <= 0) return 0;
    return n > 200 ? 200 : n;
  }

  /// Kalit massivi savollar soniga moslanadi (kiritilganlar saqlanadi).
  List<String> get _keys {
    final out = _key.take(_qCount).toList();
    while (out.length < _qCount) {
      out.add('');
    }
    return out;
  }

  int get _filled => _keys.where((k) => k.isNotEmpty).length;

  void _setAnswer(int i, String letter) {
    final next = _keys;
    next[i] = next[i] == letter ? '' : letter;
    setState(() => _key = next);
  }

  /// Kalitni matndan to'ldirish: "abcdab..." — faqat ruxsat etilgan harflar tartib bilan olinadi.
  void _applyBulk() {
    final allowed = _letters.take(_options).toList();
    final letters = _bulkKey.text
        .toUpperCase()
        .split('')
        .where((ch) => allowed.contains(ch))
        .toList();
    if (letters.isEmpty) {
      setState(() => _error = 'Kalit topilmadi — masalan: abcdabcd...');
      return;
    }
    final next = letters.take(_qCount).toList();
    while (next.length < _qCount) {
      next.add('');
    }
    setState(() {
      _key = next;
      _bulkKey.clear();
      _error = null;
    });
  }

  Future<void> _pickFile() async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      // file_picker 11: `FilePicker.platform` o'rniga statik `pickFiles`.
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'doc', 'docx'],
        withData: true,
      );
      final file = res?.files.firstOrNull;
      if (file == null) {
        if (mounted) setState(() => _uploading = false);
        return;
      }
      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) {
          setState(() {
            _uploading = false;
            _error = "Faylni o'qib bo'lmadi";
          });
        }
        return;
      }
      final up = await TeacherApi.uploadTestFile(bytes, file.name);
      if (!mounted) return;
      setState(() {
        _pdfUrl = up.url;
        _pdfName = up.name;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(context: context, initialTime: isStart ? _start : _end);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  int get _startMinutes => _start.hour * 60 + _start.minute;
  int get _endMinutes => _end.hour * 60 + _end.minute;

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Test nomi kiritilmagan');
      return;
    }
    final dateIso = _isoDate(_date);
    OnlineTest online;
    double finalMax;

    if (_online) {
      if (_qCount <= 0) {
        setState(() => _error = "Savollar soni 1 dan 200 gacha bo'lishi kerak");
        return;
      }
      if (_pdfUrl.isEmpty) {
        setState(() => _error = 'Test savollari faylini yuklang');
        return;
      }
      if (_filled != _qCount) {
        setState(() => _error = "Javoblar kaliti to'liq emas ($_filled/$_qCount)");
        return;
      }
      if (_endMinutes <= _startMinutes) {
        setState(() => _error = "Tugash vaqti boshlanish vaqtidan keyin bo'lishi kerak");
        return;
      }
      online = OnlineTest(
        mode: 'online',
        pdfUrl: _pdfUrl,
        pdfName: _pdfName,
        questionCount: _qCount,
        optionCount: _options,
        answerKey: _keys.join(),
        startAt: '${dateIso}T${_hhmm(_start)}',
        endAt: '${dateIso}T${_hhmm(_end)}',
      );
      // Onlayn testda har savol — 1 ball.
      finalMax = _qCount.toDouble();
    } else {
      final max = double.tryParse(_maxScore.text.trim().replaceAll(',', '.'));
      if (max == null || max <= 0) {
        setState(() => _error = "Maksimal ball 0 dan katta bo'lishi kerak");
        return;
      }
      online = const OnlineTest(mode: 'offline');
      finalMax = max;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.editing != null) {
        await TeacherApi.updateTest(widget.editing!.id,
            name: name, date: dateIso, maxScore: finalMax, online: online);
      } else {
        await TeacherApi.createTest(
            groupId: widget.groupId, name: name, date: dateIso, maxScore: finalMax, online: online);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(AppColors c, String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.muted),
        filled: true,
        fillColor: c.surface2,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.accent, width: 1.5)),
      );

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
            color: c.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 14),
              Text(widget.editing != null ? 'Testni tahrirlash' : 'Yangi test',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text)),
              const SizedBox(height: 14),

              // Rejim tanlash — oflayn / onlayn (bot).
              Row(
                children: [
                  Expanded(
                    child: _modeTile(c,
                        icon: Icons.assignment_outlined,
                        title: 'Oflayn',
                        sub: "Ballni qo'lda kiritasiz",
                        active: !_online,
                        onTap: () => setState(() => _online = false)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _modeTile(c,
                        icon: Icons.smart_toy_outlined,
                        title: 'Onlayn (bot)',
                        sub: "O'quvchi botdan ishlaydi",
                        active: _online,
                        onTap: () => setState(() => _online = true)),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              TextField(controller: _name, style: TextStyle(color: c.text), decoration: _dec(c, 'Test nomi')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: _dec(c, 'Sana'),
                        child: Text(fmtDate(_date.toIso8601String()), style: TextStyle(color: c.text)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _online
                        ? InputDecorator(
                            decoration: _dec(c, 'Maksimal ball'),
                            child: Text(
                              _qCount == 0 ? '—' : '$_qCount (har savol 1 ball)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: c.muted, fontSize: 13),
                            ),
                          )
                        : TextField(
                            controller: _maxScore,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(color: c.text),
                            decoration: _dec(c, 'Maksimal ball'),
                          ),
                  ),
                ],
              ),

              if (_online) ...[
                const SizedBox(height: 14),
                _fileField(c),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _count,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: c.text),
                        decoration: _dec(c, 'Savollar soni'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InputDecorator(
                        decoration: _dec(c, 'Variantlar'),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _options,
                            isDense: true,
                            isExpanded: true,
                            dropdownColor: c.surface,
                            style: TextStyle(color: c.text, fontSize: 14),
                            items: [
                              for (final n in [2, 3, 4, 5, 6])
                                DropdownMenuItem(value: n, child: Text('A–${_letters[n - 1]} ($n ta)')),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              // Ruxsat etilmagan harflar tozalanadi (masalan 5→4 bo'lsa "E").
                              final allowed = _letters.take(v).toList();
                              setState(() {
                                _options = v;
                                _key = _key.map((k) => allowed.contains(k) ? k : '').toList();
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _pickTime(true),
                        child: InputDecorator(
                          decoration: _dec(c, 'Boshlanishi'),
                          child: Text(_hhmm(_start), style: TextStyle(color: c.text)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _pickTime(false),
                        child: InputDecorator(
                          decoration: _dec(c, 'Tugashi'),
                          child: Text(_hhmm(_end), style: TextStyle(color: c.text)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "O'quvchi javoblarni faqat shu vaqt oralig'ida yubora oladi (${fmtDate(_date.toIso8601String())}).",
                  style: TextStyle(fontSize: 11, color: c.faint),
                ),
                const SizedBox(height: 14),
                _answerKeyEditor(c),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: c.redSoft, borderRadius: BorderRadius.circular(10)),
                  child: Text(_error!, style: TextStyle(color: c.red, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 16),
              SButton('Saqlash',
                  icon: Icons.check_rounded, loading: _saving, large: true, onTap: _submit),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeTile(
    AppColors c, {
    required IconData icon,
    required String title,
    required String sub,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: active ? c.accentSoft : c.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? c.accent : c.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: active ? c.accent : c.faint),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: active ? c.text : c.muted)),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: c.faint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileField(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TEST SAVOLLARI (PDF / RASM)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.faint, letterSpacing: 0.3)),
        const SizedBox(height: 8),
        if (_pdfUrl.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Icon(Icons.description_rounded, size: 18, color: c.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_pdfName.isEmpty ? 'test.pdf' : _pdfName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _pdfUrl = '';
                    _pdfName = '';
                  }),
                  child: Icon(Icons.delete_outline_rounded, size: 20, color: c.faint),
                ),
              ],
            ),
          )
        else
          GestureDetector(
            onTap: _uploading ? null : _pickFile,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border, width: 1.5),
                color: c.surface2,
              ),
              child: _uploading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
                        const SizedBox(width: 8),
                        Text('Yuklanmoqda...', style: TextStyle(fontSize: 13, color: c.muted)),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_rounded, size: 18, color: c.muted),
                        const SizedBox(width: 8),
                        Text("Faylni tanlang (20 MB gacha)",
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.muted)),
                      ],
                    ),
            ),
          ),
        const SizedBox(height: 6),
        Text("Shu fayl o'quvchiga Telegram botda yuboriladi.",
            style: TextStyle(fontSize: 11, color: c.faint)),
      ],
    );
  }

  Widget _answerKeyEditor(AppColors c) {
    final keys = _keys;
    final complete = _filled == _qCount && _qCount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text("TO'G'RI JAVOBLAR KALITI",
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800, color: c.faint, letterSpacing: 0.3)),
            ),
            Text('$_filled/$_qCount to\'ldirildi',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: complete ? c.green : c.amber)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _bulkKey,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(color: c.text),
                decoration: _dec(c, 'Tez to\'ldirish: abcdabcd...'),
                onSubmitted: (_) => _applyBulk(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 104,
              child: SButton("To'ldirish", kind: BtnKind.soft, onTap: _applyBulk),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(maxHeight: 320),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: _qCount == 0
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Savollar sonini kiriting', style: TextStyle(fontSize: 12.5, color: c.faint)),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _qCount,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text('${i + 1}.',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: c.faint)),
                      ),
                      const SizedBox(width: 6),
                      for (final letter in _letters.take(_options)) ...[
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _setAnswer(i, letter),
                            child: Container(
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: keys[i] == letter ? c.accent : c.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: keys[i] == letter ? c.accent : c.border),
                              ),
                              child: Text(letter,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: keys[i] == letter ? Colors.white : c.muted)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/* ============================ Yordamchilar ============================ */

/// Javob varianti harflari (A, B, C, ...).
const _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

/// Sonni ortiqcha nol'siz ko'rsatish (100.0 → "100", 87.5 → "87.5").
String _num(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

/// "2026-07-22T09:30" → "09:30" (bo'sh/noto'g'ri bo'lsa — zaxira qiymat).
String _timeOf(String iso, String fallback) => iso.length >= 16 ? iso.substring(11, 16) : fallback;

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
