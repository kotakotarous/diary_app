import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../services/print_label_service.dart';

class ThermalPrintScreen extends StatefulWidget {
  const ThermalPrintScreen({super.key});

  @override
  State<ThermalPrintScreen> createState() => _ThermalPrintScreenState();
}

class _ThermalPrintScreenState extends State<ThermalPrintScreen> {
  final _modelCtrl = TextEditingController();
  final _janCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Uint8List? _logoBytes;
  String? _logoName;
  bool _printing = false;
  Object? _previewKey;

  @override
  void dispose() {
    _modelCtrl.dispose();
    _janCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _logoBytes = result.files.single.bytes;
        _logoName = result.files.single.name;
      });
    }
  }

  void _refreshPreview() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _previewKey = Object());
  }

  Future<void> _print() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _printing = true);
    try {
      await PrintLabelService().printLabel(
        modelNumber: _modelCtrl.text.trim(),
        janCode: _janCtrl.text.trim(),
        logoImageBytes: _logoBytes,
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Widget _buildForm(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('ラベル設定', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),

            // 型番
            TextFormField(
              controller: _modelCtrl,
              decoration: const InputDecoration(
                labelText: 'インク型番 *',
                hintText: 'BC-340BK',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_offer_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '型番を入力してください' : null,
            ),
            const SizedBox(height: 16),

            // JANコード
            TextFormField(
              controller: _janCtrl,
              decoration: const InputDecoration(
                labelText: 'JANコード（13桁）*',
                hintText: '4901234567890',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code),
                counterText: '',
              ),
              keyboardType: TextInputType.number,
              maxLength: 13,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'JANコードを入力してください';
                if (!RegExp(r'^\d{13}$').hasMatch(v.trim())) {
                  return '13桁の数字で入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // メーカーロゴ
            Text('メーカーロゴ（任意）',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickLogo,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _logoName ?? '画像ファイルを選択（PNG / JPG）',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_logoBytes != null) ...[
              const SizedBox(height: 8),
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(8),
                    width: double.infinity,
                    child: Image.memory(_logoBytes!, height: 52,
                        fit: BoxFit.contain),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    tooltip: 'ロゴを削除',
                    onPressed: () =>
                        setState(() { _logoBytes = null; _logoName = null; }),
                  ),
                ],
              ),
            ],

            const Spacer(),

            // 用紙サイズ表示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.straighten,
                      size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    '用紙: 58mm × 40mm（サーマル）',
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _refreshPreview,
              icon: const Icon(Icons.preview_outlined),
              label: const Text('プレビューを更新'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _printing ? null : _print,
              icon: _printing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.print),
              label: const Text('印刷する'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              Text('プレビュー',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 8),
              Text('(58mm 実寸拡大)',
                  style: TextStyle(
                      fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _previewKey != null
              ? PdfPreview(
                  key: ValueKey(_previewKey),
                  build: (_) => PrintLabelService().buildPdfBytes(
                    modelNumber: _modelCtrl.text.trim(),
                    janCode: _janCtrl.text.trim(),
                    logoImageBytes: _logoBytes,
                  ),
                  initialPageFormat: PrintLabelService.labelFormat,
                  maxPageWidth: 400,
                  allowPrinting: false,
                  allowSharing: false,
                  showPageNumbers: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  useActions: false,
                  pdfFileName: 'ink_label.pdf',
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.label_outline,
                            size: 56, color: cs.outlineVariant),
                        const SizedBox(height: 16),
                        Text(
                          '型番とJANコードを入力して\n「プレビューを更新」ボタンを押すと\nラベルの仕上がりを確認できます',
                          style: TextStyle(color: cs.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 700;

    final body = isNarrow
        ? SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 520, child: _buildForm(context)),
                const Divider(),
                SizedBox(height: 420, child: _buildPreview(context)),
              ],
            ),
          )
        : Row(
            children: [
              SizedBox(width: 340, child: _buildForm(context)),
              const VerticalDivider(width: 1),
              Expanded(child: _buildPreview(context)),
            ],
          );

    return Column(
      children: [
        AppBar(
          title: const Text('インクラベル印刷'),
          automaticallyImplyLeading: false,
        ),
        Expanded(child: body),
      ],
    );
  }
}
