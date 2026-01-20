/// Google Drive Storage Service
/// 
/// This service is currently disabled to avoid dependency conflicts.
/// 
/// To enable Google Drive integration:
/// 1. Add these dependencies to pubspec.yaml:
///    - google_sign_in: ^6.1.6
///    - googleapis: ^11.4.0
///    - googleapis_auth: ^1.4.1
/// 
/// 2. Set up Google Cloud Project:
///    - Enable Google Drive API
///    - Create OAuth 2.0 credentials
///    - Add SHA-1 fingerprint
/// 
/// 3. Uncomment the code below and rebuild

class StorageService {
  static Future<bool> uploadToGoogleDrive({
    required String pdfPath,
    required String xlsxPath,
    required String reportName,
  }) async {
    // Google Drive integration disabled
    // To enable, follow setup instructions in comments above
    return false;
  }

  static Future<void> signOut() async {
    // Google Drive integration disabled
  }
}

/* FULL IMPLEMENTATION (Commented out to avoid dependency issues):

import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class StorageService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      drive.DriveApi.driveFileScope,
    ],
  );

  static Future<bool> uploadToGoogleDrive({
    required String pdfPath,
    required String xlsxPath,
    required String reportName,
  }) async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return false;
      }

      final authentication = await account.authentication;
      final accessToken = authentication.accessToken;
      
      if (accessToken == null) {
        return false;
      }

      final authClient = GoogleAuthClient({
        'Authorization': 'Bearer $accessToken',
      });

      final driveApi = drive.DriveApi(authClient);
      final folderId = await _getOrCreateFolder(driveApi, 'Expense Reports');

      if (await File(pdfPath).exists()) {
        await _uploadFile(
          driveApi,
          pdfPath,
          '$reportName.pdf',
          'application/pdf',
          folderId,
        );
      }

      if (await File(xlsxPath).exists()) {
        await _uploadFile(
          driveApi,
          xlsxPath,
          '$reportName.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          folderId,
        );
      }

      authClient.close();
      return true;
    } catch (e) {
      print('Google Drive upload error: $e');
      return false;
    }
  }

  static Future<String> _getOrCreateFolder(
    drive.DriveApi driveApi,
    String folderName,
  ) async {
    try {
      final query = "name='$folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";
      final fileList = await driveApi.files.list(
        q: query,
        spaces: 'drive',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id!;
      }

      final folder = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await driveApi.files.create(folder);
      return createdFolder.id!;
    } catch (e) {
      print('Error creating/finding folder: $e');
      rethrow;
    }
  }

  static Future<void> _uploadFile(
    drive.DriveApi driveApi,
    String filePath,
    String fileName,
    String mimeType,
    String? folderId,
  ) async {
    final file = File(filePath);
    final fileBytes = await file.readAsBytes();

    final driveFile = drive.File()
      ..name = fileName
      ..parents = folderId != null ? [folderId] : null;

    final media = drive.Media(
      Stream.value(fileBytes),
      fileBytes.length,
      contentType: mimeType,
    );

    await driveApi.files.create(
      driveFile,
      uploadMedia: media,
    );
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
*/