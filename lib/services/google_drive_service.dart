import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as gdrive;
import 'google_auth_desktop.dart' if (dart.library.html) 'google_auth_web.dart';
import 'google_auth_interface.dart';

class GoogleDriveService {
  static final instance = GoogleDriveService._();
  GoogleDriveService._();

  static const _backupFileName = 'diary_backup.json';
  final GoogleAuthInterface _auth = GoogleAuthImpl.instance;

  Future<String?> _findFileId(gdrive.DriveApi api) async {
    final list = await api.files.list(
      spaces: 'appDataFolder',
      $fields: 'files(id,name,modifiedTime)',
    );
    return list.files?.where((f) => f.name == _backupFileName).firstOrNull?.id;
  }

  Future<DateTime?> lastBackupTime() async {
    return _auth.withClient((client) async {
      final api = gdrive.DriveApi(client);
      final list = await api.files.list(
        spaces: 'appDataFolder',
        $fields: 'files(id,name,modifiedTime)',
      );
      return list.files
          ?.where((f) => f.name == _backupFileName)
          .firstOrNull
          ?.modifiedTime;
    });
  }

  Future<void> upload(String jsonContent) async {
    return _auth.withClient((client) async {
      final api = gdrive.DriveApi(client);
      final bytes = utf8.encode(jsonContent);
      final media = gdrive.Media(
        Stream.value(bytes),
        bytes.length,
        contentType: 'application/json',
      );
      final existingId = await _findFileId(api);
      if (existingId != null) {
        await api.files.update(gdrive.File(), existingId, uploadMedia: media);
      } else {
        final file = gdrive.File()
          ..name = _backupFileName
          ..parents = ['appDataFolder'];
        await api.files.create(file, uploadMedia: media);
      }
    });
  }

  Future<String?> download() async {
    return _auth.withClient((client) async {
      final api = gdrive.DriveApi(client);
      final id = await _findFileId(api);
      if (id == null) return null;
      final response = await api.files.get(
        id,
        downloadOptions: gdrive.DownloadOptions.fullMedia,
      ) as gdrive.Media;
      final bytes = await response.stream.expand((x) => x).toList();
      return utf8.decode(bytes);
    });
  }
}
