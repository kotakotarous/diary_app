import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';
import '../services/google_calendar_service.dart';
import '../services/google_drive_service.dart';

class GoogleCalendarView extends StatefulWidget {
  final List<DiaryEntry> diaryEntries;
  final Future<void> Function(DiaryEntry) onAddEntry;
  final Future<void> Function(List<DiaryEntry>) onRestoreEntries;

  const GoogleCalendarView({
    super.key,
    required this.diaryEntries,
    required this.onAddEntry,
    required this.onRestoreEntries,
  });

  @override
  State<GoogleCalendarView> createState() => _GoogleCalendarViewState();
}

class _GoogleCalendarViewState extends State<GoogleCalendarView> {
  final _svc   = GoogleCalendarService.instance;
  final _drive = GoogleDriveService.instance;

  List<GoogleCalendarEvent>? _events;
  bool _loading    = false;
  String? _error;
  bool _isLoggedIn = false;
  bool _hasClientId = false;

  DateTime? _lastBackup;
  bool _driveLoading = false;

  final _idCtrl     = TextEditingController();
  final _secretCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _svc.loadSaved();
    setState(() {
      _hasClientId = _svc.hasClientId;
      _isLoggedIn  = _svc.isLoggedIn;
      if (_svc.callbackError != null) _error = _svc.callbackError;
    });
    if (_isLoggedIn) {
      await _fetch();
      await _loadLastBackup();
    }
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final events = await _svc.fetchEvents();
      setState(() { _events = events; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadLastBackup() async {
    try {
      final t = await _drive.lastBackupTime();
      setState(() => _lastBackup = t);
    } catch (_) {}
  }

  Future<void> _saveCredentials() async {
    final id     = _idCtrl.text.trim();
    final secret = _secretCtrl.text.trim();
    if (id.isEmpty) return;
    await _svc.saveClientId(id, secret.isEmpty ? null : secret);
    setState(() => _hasClientId = true);
  }

  Future<void> _authenticate() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _svc.signIn();
      setState(() { _isLoggedIn = true; _loading = false; });
      await _fetch();
      await _loadLastBackup();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _signOut() async {
    await _svc.signOut();
    setState(() { _isLoggedIn = false; _events = null; _lastBackup = null; });
  }

  Future<void> _backup() async {
    setState(() => _driveLoading = true);
    try {
      final json = jsonEncode(
          widget.diaryEntries.map((e) => e.toJson()).toList());
      await _drive.upload(json);
      await _loadLastBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Driveにバックアップしました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('バックアップ失敗: $e')));
      }
    } finally {
      setState(() => _driveLoading = false);
    }
  }

  Future<void> _restore() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Driveから復元'),
        content: const Text(
            'Driveのバックアップデータで現在の日記を上書きします。\nよろしいですか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('復元する')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _driveLoading = true);
    try {
      final raw = await _drive.download();
      if (raw == null) throw Exception('Driveにバックアップが見つかりません');
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      await widget.onRestoreEntries(list);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${list.length}件を復元しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('復元失敗: $e')));
      }
    } finally {
      setState(() => _driveLoading = false);
    }
  }

  bool _isDuplicate(GoogleCalendarEvent ev) {
    return widget.diaryEntries.any((d) =>
        d.date.year == ev.start.year &&
        d.date.month == ev.start.month &&
        d.date.day == ev.start.day &&
        (d.title == ev.title || d.content.contains(ev.title)));
  }

  DiaryEntry _eventToEntry(GoogleCalendarEvent ev) {
    final buf = StringBuffer(ev.title);
    if (ev.location != null && ev.location!.isNotEmpty) {
      buf.write('\n場所: ${ev.location}');
    }
    if (ev.description != null && ev.description!.isNotEmpty) {
      final desc = ev.description!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      if (desc.isNotEmpty) buf.write('\n\n$desc');
    }
    return DiaryEntry(
      id: 'gcal_${ev.id}',
      date: ev.start,
      title: ev.title,
      content: buf.toString(),
      tags: ['Googleカレンダー'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!_hasClientId) {
      return _SetupScreen(
        idCtrl: _idCtrl,
        secretCtrl: _secretCtrl,
        onSave: _saveCredentials,
        isWeb: kIsWeb,
      );
    }

    if (!_isLoggedIn) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔗', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text('Googleアカウントと連携する',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('カレンダー閲覧・Driveバックアップが利用できます',
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 24),
            if (_loading) const CircularProgressIndicator(),
            if (!_loading)
              FilledButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.login),
                label: const Text('Googleでログイン'),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Text(_error!,
                    style: TextStyle(color: cs.error, fontSize: 12)),
              ),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _hasClientId = false),
              child: const Text('設定を変更'),
            ),
          ],
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: cs.error)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetch, child: const Text('再試行')),
          ],
        ),
      );
    }

    final events = _events ?? [];
    return Column(
      children: [
        // ===== アカウント情報バー =====
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: cs.primaryContainer.withValues(alpha: 0.3),
          child: Row(
            children: [
              const Icon(Icons.account_circle, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _svc.userName ?? 'Googleアカウント',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (_svc.userEmail != null)
                      Text(_svc.userEmail!,
                          style: TextStyle(fontSize: 11, color: cs.outline)),
                  ],
                ),
              ),
              if (_driveLoading)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else ...[
                TextButton.icon(
                  onPressed: _backup,
                  icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('バックアップ', style: TextStyle(fontSize: 11)),
                      if (_lastBackup != null)
                        Text(
                          DateFormat('M/d HH:mm')
                              .format(_lastBackup!.toLocal()),
                          style:
                              TextStyle(fontSize: 9, color: cs.outline),
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _restore,
                  icon: const Icon(Icons.cloud_download_outlined, size: 16),
                  label: const Text('復元', style: TextStyle(fontSize: 11)),
                ),
              ],
              TextButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('ログアウト', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),

        // ===== カレンダーヘッダー =====
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: cs.surfaceContainerHighest,
          child: Row(
            children: [
              const Text('📅', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Googleカレンダー',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('${events.length}件（過去90日〜今後30日）',
                      style: TextStyle(fontSize: 11, color: cs.outline)),
                ],
              ),
              const Spacer(),
              IconButton(
                  onPressed: _fetch,
                  icon: const Icon(Icons.refresh),
                  tooltip: '更新'),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: events.isEmpty
              ? const Center(child: Text('イベントが見つかりませんでした'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final ev = events[i];
                    final dup = _isDuplicate(ev);
                    return _EventTile(
                      event: ev,
                      isDuplicate: dup,
                      onImport: dup
                          ? null
                          : () async {
                              await widget.onAddEntry(_eventToEntry(ev));
                              setState(() {});
                            },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  final GoogleCalendarEvent event;
  final bool isDuplicate;
  final VoidCallback? onImport;

  const _EventTile({
    required this.event,
    required this.isDuplicate,
    this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final w = weekdays[event.start.weekday - 1];
    final dateStr =
        '${DateFormat('yyyy年M月d日', 'ja').format(event.start)}（$w）';
    final timeStr =
        event.isAllDay ? '終日' : DateFormat('HH:mm').format(event.start);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr, style: TextStyle(fontSize: 11, color: cs.outline)),
                Text(timeStr,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.primary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                if (event.location != null && event.location!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.place, size: 12, color: cs.outline),
                        const SizedBox(width: 2),
                        Text(event.location!,
                            style:
                                TextStyle(fontSize: 11, color: cs.outline)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isDuplicate)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  Text('取込済み', style: TextStyle(fontSize: 11, color: cs.outline)),
            )
          else
            FilledButton.tonal(
              onPressed: onImport,
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
              ),
              child: const Text('日記に追加', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

class _SetupScreen extends StatelessWidget {
  final TextEditingController idCtrl;
  final TextEditingController secretCtrl;
  final VoidCallback onSave;
  final bool isWeb;

  const _SetupScreen({
    required this.idCtrl,
    required this.secretCtrl,
    required this.onSave,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Googleアカウント連携の設定',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (isWeb) ...[
                Text(
                  'Google Cloud ConsoleでOAuth2クライアントIDを作成してください。\n'
                  'ウェブ版ではClient IDとClient Secretが必要です。',
                  style:
                      TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  '手順:\n'
                  '① console.cloud.google.com → 認証情報 → OAuthクライアントID\n'
                  '② 種類：「ウェブアプリケーション」\n'
                  '③ 承認済みJavaScriptオリジン → 追加:\n'
                  '   https://kotakotarous.github.io\n'
                  '④ 承認済みリダイレクトURI → 追加:\n'
                  '   https://kotakotarous.github.io/diary_app/\n'
                  '⑤ Calendar API・Drive API を有効化',
                  style: TextStyle(fontSize: 11, color: cs.outline),
                ),
              ] else ...[
                Text(
                  'Google Cloud ConsoleでOAuth2クライアントIDを作成し、\n'
                  '"デスクトップアプリ"タイプのClient IDとSecretを入力してください。',
                  style:
                      TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  '手順: console.cloud.google.com → 認証情報 → OAuthクライアントID\n'
                  '→ アプリの種類：「デスクトップアプリ」\n'
                  '→ Calendar API・Drive API を有効化',
                  style: TextStyle(fontSize: 11, color: cs.outline),
                ),
              ],
              const SizedBox(height: 24),
              TextField(
                controller: idCtrl,
                decoration: const InputDecoration(
                  labelText: 'Client ID',
                  hintText: 'xxxxxx.apps.googleusercontent.com',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secretCtrl,
                decoration: const InputDecoration(
                  labelText: 'Client Secret',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onSave,
                child: const Text('保存して接続'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
