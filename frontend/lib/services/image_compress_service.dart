import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageCompressService {
  ImageCompressService._();

  static final ImageCompressService instance = ImageCompressService._();

  Future<File> compressAndPersist(XFile source) async {
    final sourceFile = File(source.path);
    final bytes = await _compress(source.path);
    final dir = await _getQueueDir();
    final fileName = _buildFileName();
    final target = File('${dir.path}/$fileName');
    if (bytes != null && bytes.isNotEmpty) {
      await target.writeAsBytes(bytes, flush: true);
      return target;
    }

    // Fallback for unsupported formats: keep original bytes but persist to app directory.
    return sourceFile.copy(target.path);
  }

  Future<Uint8List?> _compress(String path) {
    return FlutterImageCompress.compressWithFile(
      path,
      minWidth: 1920,
      minHeight: 1920,
      quality: 75,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
  }

  Future<Directory> _getQueueDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/pending_uploads');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _buildFileName() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'upload_${now}_$random.jpg';
  }
}
