import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'google_auth_interface.dart';

const _scopes = [
  'https://www.googleapis.com/auth/calendar.readonly',
  'https://www.googleapis.com/auth/drive.appdata',
  'email',
  'profile',
];
const _prefClientId = 'google_web_client_id';

class GoogleAuthImpl extends GoogleAuthInterface {
  static final instance = GoogleAuthImpl._();
  GoogleAuthImpl._();

  GoogleSignIn? _signIn;
  GoogleSignInAccount? _account;
  String? _clientId;

  @override bool get hasClientId => _clientId != null && _clientId!.isNotEmpty;
  @override bool get isLoggedIn  => _account != null;
  @override String? get userEmail => _account?.email;
  @override String? get userName  => _account?.displayName;

  @override
  Future<bool> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    _clientId = prefs.getString(_prefClientId);
    if (!hasClientId) return false;
    _signIn = GoogleSignIn(clientId: _clientId, scopes: _scopes);
    try {
      _account = await _signIn!.signInSilently();
    } catch (_) {}
    return true;
  }

  @override
  Future<void> saveClientId(String clientId, [String? clientSecret]) async {
    _clientId = clientId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefClientId, clientId);
    _signIn = GoogleSignIn(clientId: clientId, scopes: _scopes);
  }

  @override
  Future<void> signIn() async {
    _signIn ??= GoogleSignIn(clientId: _clientId, scopes: _scopes);
    _account = await _signIn!.signIn();
    if (_account == null) throw Exception('サインインがキャンセルされました');
  }

  @override
  Future<void> signOut() async {
    await _signIn?.signOut();
    _account = null;
  }

  @override
  Future<T> withClient<T>(Future<T> Function(http.Client client) fn) async {
    if (_account == null) throw Exception('未認証');
    // トークン更新を試みる
    _account = await _signIn!.signInSilently() ?? _account;
    final auth = await _account!.authentication;
    final token = auth.accessToken;
    if (token == null) throw Exception('アクセストークンが取得できませんでした');
    final client = _BearerClient(token);
    try {
      return await fn(client);
    } finally {
      client.close();
    }
  }
}

/// Bearer トークンをヘッダーに付与する HTTP クライアント
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
