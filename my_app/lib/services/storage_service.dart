import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final storageServiceProvider = Provider((ref) => StorageService());

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a list of files to Firebase Storage and returns their download URLs.
  Future<List<String>> uploadFiles(List<PlatformFile> files, String folder) async {
    List<String> downloadUrls = [];

    for (var file in files) {
      try {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final destination = '$folder/$fileName';
        final ref = _storage.ref(destination);

        UploadTask task;
        if (kIsWeb) {
          // For Web, use bytes
          task = ref.putData(file.bytes!);
        } else {
          // For Mobile/Desktop, use file path
          task = ref.putFile(File(file.path!));
        }

        final snapshot = await task;
        final url = await snapshot.ref.getDownloadURL();
        downloadUrls.add(url);
      } catch (e) {
        debugPrint("Upload Error: $e");
      }
    }

    return downloadUrls;
  }
}
