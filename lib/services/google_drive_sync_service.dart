import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'local_storage_service.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleDriveSyncService {
  static const _backupFileName = 'highwayrx_backup_v1.json';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  static Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (e) {
      debugPrint('Google Sign-In failed: $e');
      return null;
    }
  }

  static Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (e) {
      return null;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  static Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  static Future<GoogleSignInAccount?> getCurrentUser() async {
    return _googleSignIn.currentUser;
  }

  static Future<drive.DriveApi?> _getDriveApi() async {
    var account = _googleSignIn.currentUser ?? await signInSilently();
    if (account == null) return null;

    final headers = await account.authHeaders;
    final client = GoogleAuthClient(headers);
    return drive.DriveApi(client);
  }

  static Future<bool> hasBackup() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return false;

    try {
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName'",
      );
      return fileList.files != null && fileList.files!.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> backupData() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return false;

    try {
      final jsonString = await LocalStorageService.exportData();
      final bytes = utf8.encode(jsonString);
      final media = drive.Media(Stream.value(bytes), bytes.length);

      // Check if backup already exists
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName'",
      );

      final files = fileList.files;
      if (files != null && files.isNotEmpty) {
        // Update existing file
        final fileId = files.first.id!;
        await driveApi.files.update(drive.File(), fileId, uploadMedia: media);
      } else {
        // Create new file
        final fileToUpload = drive.File()
          ..name = _backupFileName
          ..parents = ['appDataFolder'];
        await driveApi.files.create(fileToUpload, uploadMedia: media);
      }

      await LocalStorageService.setLastBackupDate(DateTime.now());
      return true;
    } catch (e) {
      debugPrint('Backup failed: $e');
      return false;
    }
  }

  static Future<bool> restoreData() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return false;

    try {
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName'",
      );

      final files = fileList.files;
      if (files == null || files.isEmpty) return false;

      final fileId = files.first.id!;
      final response = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      if (response is drive.Media) {
        final List<int> bytes = [];
        await for (var chunk in response.stream) {
          bytes.addAll(chunk);
        }
        final jsonString = utf8.decode(bytes);
        await LocalStorageService.importData(jsonString);
        await LocalStorageService.setLastBackupDate(DateTime.now());
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Restore failed: $e');
      return false;
    }
  }

  static Future<bool> performDailyBackupIfNeeded() async {
    final account = await signInSilently();
    if (account == null) return false;

    final lastBackup = await LocalStorageService.getLastBackupDate();
    if (lastBackup == null ||
        DateTime.now().difference(lastBackup).inDays >= 1) {
      return await backupData();
    }
    return false;
  }
}
