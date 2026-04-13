// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'google_auth_interface.dart';

const _scopes = [
  'https://www.googleapis.com/auth/calendar.readonly',
  'https://www.googleapis.com/auth/drive.appdata',
  'email',
  'profile',
  'openid',
];

const _prefClientId     = 'google_web_client_id';
const _prefClientSecret = 'google_web_client_secret';
const _prefAccessToken  = 'google_web_access_token';
const _prefExpiry       = 'google_web_token_expiry';
const _prefEmail        = 'google_web_email';
const _prefName         = 'google_web_name';
const _sessionVerifier  = 'google_pkce_verifier';

class GoogleAuthImpl extends GoogleAuthInterface {
  static final instance = GoogleAuthImpl._();
  GoogleAuthImpl._();

  String? _clientId;
  String? _clientSecret;
  String? _accessToken;
  DateTime? _expiry;
  String? _userEmail;
  String? _userName;
  String? _callbackError;

  @override
  String? get callbackError => _callbackError;

  @override
  bool get hasClientId => _clientId != null && _clientId!.isNotEmpty;

  @override
  bool get isLoggedIn =>
      _accessToken != null &&
      (_expiry == null || _expiry!.isAfter(DateTime.now()));

  @override
  String? get userEmail => _userEmail;

  @override
  String? get userName => _userName;

  @override
  Future<bool> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    _clientId     = prefs.getString(_prefClientId);
    _clientSecret = prefs.getString(_prefClientSecret);

    // OAuthコールバックの処理（URLに ?code= がある場合）
    final uri = Uri.parse(html.window.location.href);
    final code = uri.queryParameters['code'];
    if (code != null && hasClientId) {
      await _handleCallback(code, prefs);
    }

    // 保存済みトークンを読み込む
    _accessToken = prefs.getString(_prefAccessToken);
    final expiryStr = prefs.getString(_prefExpiry);
    if (expiryStr != null) _expiry = DateTime.tryParse(expiryStr);
    _userEmail = prefs.getString(_prefEmail);
    _userName  = prefs.getString(_prefName);

    return hasClientId;
  }

  Future<void> _handleCallback(String code, SharedPreferences prefs) async {
    final verifier = html.window.sessionStorage[_sessionVerifier];
    if (verifier == null) {
      _callbackError = 'セッションが見つかりません。もう一度「Googleでログイン」を押してください。';
      return;
    }

    try {
      final resp = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'code': code,
          'client_id': _clientId!,
          if (_clientSecret != null && _clientSecret!.isNotEmpty)
            'client_secret': _clientSecret!,
          'redirect_uri': _currentBaseUrl,
          'grant_type': 'authorization_code',
          'code_verifier': verifier,
        },
      );

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['error'] != null) {
        throw Exception('${body['error']}: ${body['error_description']}');
      }

      _accessToken = body['access_token'] as String;
      final expiresIn = (body['expires_in'] as int?) ?? 3600;
      _expiry =
          DateTime.now().toUtc().add(Duration(seconds: expiresIn));

      final idToken = body['id_token'] as String?;
      if (idToken != null) _parseIdToken(idToken);

      await prefs.setString(_prefAccessToken, _accessToken!);
      await prefs.setString(_prefExpiry, _expiry!.toIso8601String());
      if (_userEmail != null) await prefs.setString(_prefEmail, _userEmail!);
      if (_userName  != null) await prefs.setString(_prefName,  _userName!);

      // URLから ?code= を除去
      html.window.history.replaceState(
          null, '', html.window.location.pathname);
    } catch (e) {
      _callbackError = 'ログイン処理に失敗しました: $e';
    } finally {
      html.window.sessionStorage.remove(_sessionVerifier);
    }
  }

  void _parseIdToken(String idToken) {
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return;
      final payload = utf8.decode(
          base64Url.decode(base64Url.normalize(parts[1])));
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _userEmail = data['email'] as String?;
      _userName  = data['name']  as String?;
    } catch (_) {}
  }

  @override
  Future<void> saveClientId(String clientId, [String? clientSecret]) async {
    _clientId     = clientId;
    _clientSecret = clientSecret;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefClientId, clientId);
    if (clientSecret != null && clientSecret.isNotEmpty) {
      await prefs.setString(_prefClientSecret, clientSecret);
    }
  }

  @override
  Future<void> signIn() async {
    if (!hasClientId) throw Exception('Client IDが未設定です');

    // PKCE code_verifier を生成
    final verifier  = _generateVerifier();
    final challenge = _codeChallenge(verifier);
    html.window.sessionStorage[_sessionVerifier] = verifier;

    final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id':             _clientId!,
      'redirect_uri':          _currentBaseUrl,
      'response_type':         'code',
      'scope':                 _scopes.join(' '),
      'code_challenge':        challenge,
      'code_challenge_method': 'S256',
      'access_type':           'offline',
      'prompt':                'consent',
    });

    // ページ全体をGoogleログインにリダイレクト（ポップアップ不要）
    html.window.location.assign(authUri.toString());
  }

  @override
  Future<void> signOut() async {
    _accessToken = null;
    _expiry      = null;
    _userEmail   = null;
    _userName    = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefAccessToken);
    await prefs.remove(_prefExpiry);
    await prefs.remove(_prefEmail);
    await prefs.remove(_prefName);
  }

  @override
  Future<T> withClient<T>(Future<T> Function(http.Client client) fn) async {
    if (_accessToken == null) throw Exception('未認証');
    if (_expiry != null && _expiry!.isBefore(DateTime.now())) {
      throw Exception('セッションの有効期限が切れました。再ログインしてください。');
    }
    final client = _BearerClient(_accessToken!);
    try {
      return await fn(client);
    } finally {
      client.close();
    }
  }

  /// 現在のページURL（クエリなし）= redirect_uri に使う
  String get _currentBaseUrl {
    final loc = html.window.location;
    return '${loc.protocol}//${loc.host}${loc.pathname}';
  }

  String _generateVerifier() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _codeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
}

class _BearerClient extends http.BaseClient {
  final String _token;
  final _inner = http.Client();

  _BearerClient(this._token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
