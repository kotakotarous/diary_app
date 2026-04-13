import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:url_launcher/url_launcher.dart';
import 'google_auth_interface.dart';

const _scopes = [
  'https://www.googleapis.com/auth/calendar.readonly',
  'https://www.googleapis.com/auth/drive.appdata',
  'email',
  'profile',
];
const _tokenFile = 'google_token.json';
const _credFile  = 'google_creds.json';
const _callbackPort = 8765;

class GoogleAuthImpl extends GoogleAuthInterface {
  static final instance = GoogleAuthImpl._();
  GoogleAuthImpl._();

  ClientId? _clientId;
  AccessCredentials? _credentials;
  String? _userEmail;
  String? _userName;

  Future<String> get _docsPath async =>
      (await getApplicationDocumentsDirectory()).path;

  @override bool get hasClientId => _clientId != null;
  @override bool get isLoggedIn  => _credentials != null;
  @override String? get userEmail => _userEmail;
  @override String? get userName  => _userName;

  @override
  Future<bool> loadSaved() async {
    try {
      final path = await _docsPath;
      final credsFile = File('$path/$_credFile');
      if (!credsFile.existsSync()) return false;
      final creds = jsonDecode(await credsFile.readAsString()) as Map<String, dynamic>;
      _clientId = ClientId(
          creds['client_id'] as String, creds['client_secret'] as String);

      final tokenFile = File('$path/$_tokenFile');
      if (!tokenFile.existsSync()) return true;
      final tok = jsonDecode(await tokenFile.readAsString()) as Map<String, dynamic>;

      _userEmail = tok['email'] as String?;
      _userName  = tok['name']  as String?;

      final savedScopes = (tok['scopes'] as List<dynamic>).cast<String>();
      if (!savedScopes.contains('https://www.googleapis.com/auth/drive.appdata')) {
        return true; // hasClientId=true, isLoggedIn=false → 再認証を促す
      }

      _credentials = AccessCredentials(
        AccessToken(tok['type'] as String, tok['data'] as String,
            DateTime.parse(tok['expiry'] as String)),
        tok['refreshToken'] as String?,
        savedScopes,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> saveClientId(String clientId, [String? clientSecret]) async {
    final path = await _docsPath;
    await File('$path/$_credFile').writeAsString(jsonEncode({
      'client_id': clientId,
      'client_secret': clientSecret ?? '',
    }));
    _clientId = ClientId(clientId, clientSecret ?? '');
  }

  @override
  Future<void> signIn() async {
    if (_clientId == null) throw Exception('Client IDが未設定です');
    final completer = Completer<String>();

    final server = await shelf_io.serve(
      (req) {
        final code = req.requestedUri.queryParameters['code'];
        if (code != null && !completer.isCompleted) completer.complete(code);
        return shelf.Response.ok(
          '<html><meta charset="utf-8"><body style="font-family:sans-serif;padding:40px">'
          '<h2>✅ 認証完了</h2><p>このウィンドウを閉じてアプリに戻ってください。</p>'
          '</body></html>',
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      },
      'localhost',
      _callbackPort,
    );

    final redirectUri = 'http://localhost:$_callbackPort/callback';
    final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': _clientId!.identifier,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': _scopes.join(' '),
      'access_type': 'offline',
      'prompt': 'consent',
    });

    await launchUrl(authUri, mode: LaunchMode.externalApplication);

    late String code;
    try {
      code = await completer.future.timeout(const Duration(minutes: 3),
          onTimeout: () => throw Exception('認証タイムアウト（3分）'));
    } finally {
      await server.close();
    }

    final resp = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'code': code,
        'client_id': _clientId!.identifier,
        'client_secret': _clientId!.secret ?? '',
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
      },
    );

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (body['error'] != null) {
      throw Exception('${body['error']}: ${body['error_description']}');
    }

    final expiry = DateTime.now().toUtc()
        .add(Duration(seconds: (body['expires_in'] as int?) ?? 3600));
    _credentials = AccessCredentials(
      AccessToken('Bearer', body['access_token'] as String, expiry),
      body['refresh_token'] as String?,
      _scopes,
    );

    await _fetchUserInfo(body['access_token'] as String);
    await _saveToken();
  }

  Future<void> _fetchUserInfo(String accessToken) async {
    try {
      final res = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v1/userinfo?alt=json'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (res.statusCode == 200) {
        final info = jsonDecode(res.body) as Map<String, dynamic>;
        _userEmail = info['email'] as String?;
        _userName  = info['name']  as String?;
      }
    } catch (_) {}
  }

  Future<void> _saveToken() async {
    final path = await _docsPath;
    await File('$path/$_tokenFile').writeAsString(jsonEncode({
      'type': 'Bearer',
      'data': _credentials!.accessToken.data,
      'expiry': _credentials!.accessToken.expiry.toIso8601String(),
      'refreshToken': _credentials!.refreshToken,
      'scopes': _scopes,
      'email': _userEmail,
      'name':  _userName,
    }));
  }

  @override
  Future<void> signOut() async {
    _credentials = null;
    _userEmail = null;
    _userName  = null;
    final path = await _docsPath;
    final f = File('$path/$_tokenFile');
    if (f.existsSync()) await f.delete();
  }

  @override
  Future<T> withClient<T>(Future<T> Function(http.Client client) fn) async {
    if (_clientId == null || _credentials == null) throw Exception('未認証');
    final client = autoRefreshingClient(_clientId!, _credentials!, http.Client());
    try {
      return await fn(client);
    } finally {
      client.close();
    }
  }
}
