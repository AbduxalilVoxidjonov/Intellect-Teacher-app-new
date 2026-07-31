import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_client.dart';
import '../api/teacher_api.dart';
import '../config.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';

/// Shartnoma — o'qituvchi bilan tuzilgan shartnomalarning elektron (PDF) nusxalari.
/// Backend: `GET /teacher/contracts`. Kartochka bosilganda PDF tashqi ilovada ochiladi.
/// Eski yozuvlarda saqlangan fayl bo'lmasligi mumkin — bunday kartochka o'chirilgan.
class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});
  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  List<ContractDoc> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _error = null);
    try {
      final list = await TeacherApi.contracts();
      if (mounted) setState(() => _items = list);
    } on ApiException catch (e) {
      // Web `apiErrorMessage` kabi — serverning haqiqiy xabari ko'rsatiladi.
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = "Shartnomalarni yuklab bo'lmadi");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Faylni tashqi ilovada ochish (guruh testlaridagi bilan bir xil uslub).
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

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);

    Widget body;
    if (_loading) {
      body = const Center(child: Loader(label: 'Yuklanmoqda...'));
    } else if (_error != null) {
      body = _scrollWrap([
        const SizedBox(height: 40),
        EmptyState(icon: Icons.error_outline_rounded, text: _error!),
        Center(
          child: SizedBox(
            width: 180,
            child: SButton('Qayta urinish',
                icon: Icons.refresh_rounded, kind: BtnKind.soft, onTap: _load),
          ),
        ),
      ]);
    } else if (_items.isEmpty) {
      body = _scrollWrap([
        const SizedBox(height: 24),
        const EmptyState(
          icon: Icons.description_outlined,
          text: 'Shartnoma hali tuzilmagan',
        ),
      ]);
    } else {
      body = RefreshIndicator(
        color: c.accent,
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _card(c, _items[i]),
        ),
      );
    }

    return SubScaffold(title: 'Shartnoma', child: body);
  }

  Widget _scrollWrap(List<Widget> children) {
    return RefreshIndicator(
      color: AppTheme.of(context).accent,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      ),
    );
  }

  Widget _card(AppColors c, ContractDoc doc) {
    final has = doc.hasFile;
    final title = doc.title.isNotEmpty ? doc.title : 'Shartnoma № ${doc.number}';
    final card = SCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      onTap: has ? () => _openFile(doc.fileUrl) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: has ? c.accentSoft : c.surface3,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              has ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_outlined,
              size: 20,
              color: has ? c.accent : c.faint,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.text)),
                    ),
                    if (doc.signed) ...[
                      const SizedBox(width: 6),
                      SChip('Imzolangan', color: c.green, bg: c.greenSoft),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  fmtDate(doc.date),
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
                if (doc.templateName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    doc.templateName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.faint),
                  ),
                ],
                if (!has) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Fayl mavjud emas',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.faint),
                  ),
                ],
              ],
            ),
          ),
          if (has) ...[
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Icon(Icons.chevron_right_rounded, color: c.faint),
            ),
          ],
        ],
      ),
    );
    // Fayl saqlanmagan (eski) yozuv — kartochka o'chirilgan holatda ko'rinadi.
    return has ? card : Opacity(opacity: 0.55, child: card);
  }
}
