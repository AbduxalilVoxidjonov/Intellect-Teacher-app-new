import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/teacher_api.dart';
import '../theme/app_theme.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';

/// Taklif va shikoyat — tur tanlash (taklif/shikoyat) + matn (>=5 belgi) +
/// ixtiyoriy rasm biriktirish (kamera yoki galereya) + yuborish.
/// Web `feedback/FeedbackPage.tsx` bilan bir xil oqim.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  String _type = 'suggestion';
  final _controller = TextEditingController();
  bool _sending = false;
  final _picker = ImagePicker();
  Uint8List? _imageBytes;
  String? _imageName;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSend => _controller.text.trim().length >= 5 && !_sending;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2500)),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final x = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 82);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = x.name;
      });
    } catch (_) {
      _toast("Rasmni ochib bo'lmadi");
    }
  }

  void _chooseImageSource() {
    final c = AppTheme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.photo_camera_rounded, color: c.accent),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: c.accent),
              title: const Text('Galereya'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.length < 5) {
      _toast('Matn juda qisqa');
      return;
    }
    setState(() => _sending = true);
    try {
      await TeacherApi.sendFeedback(
        _type,
        text,
        imageBytes: _imageBytes,
        imageName: _imageName,
      );
      _toast('Yuborildi. Rahmat!');
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) setState(() => _sending = false);
      _toast(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SubScaffold(
      title: 'Taklif va shikoyat',
      scrollable: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.border),
                boxShadow: c.shadow,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TypeButton(
                      label: 'Taklif',
                      icon: Icons.auto_awesome_rounded,
                      active: _type == 'suggestion',
                      color: c.accent,
                      onTap: () => setState(() => _type = 'suggestion'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _TypeButton(
                      label: 'Shikoyat',
                      icon: Icons.warning_amber_rounded,
                      active: _type == 'complaint',
                      color: c.red,
                      onTap: () => setState(() => _type = 'complaint'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('Matn', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.text)),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 6,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Fikringizni yozing…',
                filled: true,
                fillColor: c.surface,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.border)),
                enabledBorder:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.border)),
                focusedBorder:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.accent, width: 1.5)),
              ),
            ),
            const SizedBox(height: 18),
            Text('Rasm (ixtiyoriy)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.text)),
            const SizedBox(height: 8),
            if (_imageBytes == null)
              InkWell(
                onTap: _sending ? null : _chooseImageSource,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_rounded, size: 20, color: c.accent),
                      const SizedBox(width: 8),
                      Text('Rasm biriktirish',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.accent)),
                    ],
                  ),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Image.memory(
                      _imageBytes!,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: InkWell(
                        onTap: _sending ? null : () => setState(() {
                          _imageBytes = null;
                          _imageName = null;
                        }),
                        child: Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 22),
            SButton(
              _sending ? 'Yuborilmoqda…' : 'Yuborish',
              icon: Icons.send_rounded,
              large: true,
              loading: _sending,
              onTap: _canSend ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _TypeButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: active ? Colors.white : c.muted),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: active ? Colors.white : c.muted)),
          ],
        ),
      ),
    );
  }
}
