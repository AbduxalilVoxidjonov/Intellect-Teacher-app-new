import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// GURUH JURNALIDAGI «ALOQA» TABI — o'quvchini "Bog'lanish kerak" navbatiga
/// yuborish (web `components/contacts/GroupContactTab.tsx` bilan bir xil).
///
/// QOIDALAR (`.claude/rules/contacts.md` §3.7):
///  • SANA SO'RALMAYDI — talab darhol navbatga tushadi (bugungi ish).
///    Rejalashtirish (qayta qo'ng'iroq sanasi) — operatorning ishi, o'qituvchining emas.
///  • SABAB va IZOH MAJBURIY: aks holda navbatga "sababsiz, izohsiz" talab
///    tushardi va operator nima uchun qo'ng'iroq qilayotganini bilmasdi.
///  • MUZLATILGANLAR RO'YXATDA KO'RINMAYDI — jurnal ularni ham qaytaradi
///    (alohida blokda), lekin ular darsga qatnamayapti. SINOVDAGILAR QOLADI —
///    aynan ular bilan bog'lanish ko'p kerak bo'ladi.
///  • Ochiq talabi bor o'quvchi serverda CHETLAB O'TILADI, butun amal
///    to'xtamaydi — shuning uchun javobdagi `created`/`skipped`/`notFound`
///    uchalasi ham foydalanuvchiga ko'rsatiladi.
class GroupContactTab extends StatefulWidget {
  /// Jurnal ro'yxatidan keladigan o'quvchilar (muzlatilganlar bilan birga —
  /// filtr SHU YERDA, chaqiruv joyida unutilib qolmasin).
  final List<GroupJournalStudent> students;

  /// Sabablar katalogi (`GET /teacher/contact-reasons`).
  final Future<List<ContactReason>> Function() loadReasons;

  /// Navbatga yuborish (`POST /teacher/groups/{classId}/contacts`).
  final Future<ContactBulkResult> Function(
    List<String> studentIds,
    String reasonId,
    String note,
  ) onSend;

  const GroupContactTab({
    super.key,
    required this.students,
    required this.loadReasons,
    required this.onSend,
  });

  @override
  State<GroupContactTab> createState() => _GroupContactTabState();
}

class _GroupContactTabState extends State<GroupContactTab> {
  List<ContactReason> _reasons = const [];
  bool _reasonsLoading = true;
  String? _reasonId;
  final _noteController = TextEditingController();
  final _searchController = TextEditingController();
  final Set<String> _selected = <String>{};
  bool _busy = false;
  String? _error;
  ContactBulkResult? _result;

  @override
  void initState() {
    super.initState();
    _loadReasons();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReasons() async {
    try {
      final list = await widget.loadReasons();
      if (!mounted) return;
      setState(() {
        _reasons = list;
        _reasonsLoading = false;
      });
    } catch (_) {
      // Sabablar yuklanmasa tab baribir ochiladi — pastda tushuntirish turadi.
      if (!mounted) return;
      setState(() {
        _reasons = const [];
        _reasonsLoading = false;
      });
    }
  }

  /// Muzlatilganlar chiqarib tashlanadi, keyin qidiruv bo'yicha filtr.
  List<GroupJournalStudent> get _filtered {
    final base = widget.students.where((s) => s.status != 'frozen');
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return base.toList();
    return base.where((s) => s.fullName.toLowerCase().contains(q)).toList();
  }

  /// Sabab va izoh to'ldirilganmi (ikkala tugma ham shunga bog'liq).
  bool get _ready => _reasonId != null && _noteController.text.trim().isNotEmpty;

  Future<void> _send(List<String> ids) async {
    if (_busy || ids.isEmpty) return;
    if (!_ready) {
      setState(() => _error = _reasonId == null ? 'Sababni tanlang' : "Izohni yozing");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final r = await widget.onSend(ids, _reasonId!, _noteController.text.trim());
      if (!mounted) return;
      setState(() {
        _result = r;
        // Yuborilganlar tanlovdan chiqadi — ikki marta bosib yuborilmasin.
        _selected.removeAll(ids);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException ? e.message : "Navbatga yuborib bo'lmadi");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final list = _filtered;
    final allSelected = list.isNotEmpty && list.every((s) => _selected.contains(s.studentId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label(c, 'Sabab *'),
              const SizedBox(height: 6),
              _reasonsLoading
                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Loader())
                  : DropdownButtonFormField<String>(
                      initialValue: _reasonId,
                      isExpanded: true,
                      decoration: _fieldDecoration(c, '— Tanlanmagan —'),
                      items: [
                        for (final r in _reasons)
                          DropdownMenuItem(value: r.id, child: Text(r.label, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: _busy ? null : (v) => setState(() => _reasonId = v),
                    ),
              if (!_reasonsLoading && _reasons.isEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  "Sabablar ro'yxati bo'sh — Sozlamalar → Sabablar da \"Bog'lanish kerak\" "
                  'kategoriyasiga sabab qo\'shilishi kerak.',
                  style: TextStyle(fontSize: 11.5, color: c.amber),
                ),
              ],
              const SizedBox(height: 14),
              _label(c, 'Izoh *'),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                maxLength: 2000,
                maxLines: 2,
                enabled: !_busy,
                onChanged: (_) => setState(() {}),
                decoration: _fieldDecoration(c, 'Masalan: darsga 3 marta kelmadi')
                    .copyWith(counterText: ''),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  "Tanlangan o'quvchilar BUGUNGI sana bilan \"Bog'lanish kerak\" navbatiga "
                  'tushadi — sana tanlash shart emas. Navbatda kim yuborgani ko\'rinib turadi. '
                  "Muzlatilgan o'quvchilar bu ro'yxatda ko'rinmaydi. Sabab va izoh majburiy.",
                  style: TextStyle(fontSize: 11.5, height: 1.5, color: c.accentD),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: _fieldDecoration(c, "O'quvchi qidirish")
                    .copyWith(prefixIcon: Icon(Icons.search_rounded, size: 18, color: c.faint)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: allSelected,
                    onChanged: list.isEmpty || _busy
                        ? null
                        : (_) => setState(() {
                              if (allSelected) {
                                _selected.removeAll(list.map((s) => s.studentId));
                              } else {
                                _selected.addAll(list.map((s) => s.studentId));
                              }
                            }),
                  ),
                  Expanded(
                    child: Text('Hammasini tanlash',
                        style: TextStyle(fontSize: 13, color: c.muted)),
                  ),
                ],
              ),
              SButton(
                _busy ? 'Yuborilmoqda…' : 'Navbatga yuborish (${_selected.length})',
                icon: Icons.phone_in_talk_rounded,
                large: true,
                loading: _busy,
                onTap: (_selected.isEmpty || !_ready || _busy) ? null : () => _send(_selected.toList()),
              ),
              if (!_ready) ...[
                const SizedBox(height: 6),
                Text("Sabab va izoh to'ldirilishi kerak",
                    style: TextStyle(fontSize: 11.5, color: c.amber)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(fontSize: 12.5, color: c.red)),
              ],
              if (_result != null) ...[
                const SizedBox(height: 8),
                _resultBox(c, _result!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (list.isEmpty)
          EmptyState(
            icon: Icons.phone_disabled_outlined,
            text: _searchController.text.trim().isEmpty
                ? "Guruhda o'quvchi yo'q"
                : 'Hech kim topilmadi',
          )
        else
          SCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < list.length; i++)
                  _row(c, list[i], last: i == list.length - 1),
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(AppColors c, GroupJournalStudent s, {required bool last}) {
    final selected = _selected.contains(s.studentId);
    return Container(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.only(right: 6),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            onChanged: _busy
                ? null
                : (_) => setState(() {
                      if (selected) {
                        _selected.remove(s.studentId);
                      } else {
                        _selected.add(s.studentId);
                      }
                    }),
          ),
          Expanded(
            child: Text(
              s.fullName,
              maxLines: 2,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.text),
            ),
          ),
          if (s.status == 'trial') ...[
            SChip('Sinov', color: c.amber, bg: c.amberSoft),
            const SizedBox(width: 6),
          ],
          // BITTA o'quvchini darhol yuborish — tanlab o'tirmasdan.
          IconButton(
            tooltip: _ready
                ? "Shu o'quvchini navbatga yuborish"
                : "Avval sabab va izohni to'ldiring",
            icon: Icon(Icons.phone_in_talk_rounded, size: 19, color: _ready ? c.accent : c.faint),
            onPressed: (!_ready || _busy) ? null : () => _send([s.studentId]),
          ),
        ],
      ),
    );
  }

  Widget _resultBox(AppColors c, ContactBulkResult r) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.greenSoft, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${r.created} ta o\'quvchi navbatga yuborildi.',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.green)),
          if (r.skipped > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${r.skipped} tasida allaqachon ochiq talab bor — qayta yuborilmadi'
              '${r.skippedNames.isEmpty ? '' : ': ${r.skippedNames.join(', ')}'}'
              '${r.skipped > r.skippedNames.length ? ' va boshqalar' : ''}',
              style: TextStyle(fontSize: 11.5, color: c.amber),
            ),
          ],
          if (r.notFound > 0) ...[
            const SizedBox(height: 4),
            Text("${r.notFound} ta o'quvchi topilmadi.",
                style: TextStyle(fontSize: 11.5, color: c.muted)),
          ],
        ],
      ),
    );
  }

  Widget _label(AppColors c, String text) =>
      Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.muted));

  InputDecoration _fieldDecoration(AppColors c, String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: c.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
      );
}
