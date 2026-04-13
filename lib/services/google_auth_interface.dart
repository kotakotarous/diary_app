import 'package:http/http.dart' as http;

/// プラットフォーム共通のGoogle認証インターフェース
abstract class GoogleAuthInterface {
  bool get hasClientId;
  bool get isLoggedIn;
  String? get userEmail;
  String? get userName;

  Future<bool> loadSaved();

  /// デスクトップ: clientId + clientSecret が必要
  /// ウェブ: clientId のみ（secret は無視）
  Future<void> saveClientId(String clientId, [String? clientSecret]);

  Future<void> signIn();
  Future<void> signOut();

  /// 認証済みHTTPクライアントを使って処理を実行し自動クローズ
  Future<T> withClient<T>(Future<T> Function(http.Client client) fn);
}
