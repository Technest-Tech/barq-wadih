import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Normalizes iPhone photos before multipart upload.
///
/// iOS can return HEIC/HEIF files even when [ImagePicker] is given an
/// `imageQuality`. The ads API intentionally accepts web-safe image formats
/// only, so iOS images are flattened, resized and encoded as JPEG natively.
class ImageUploadPreprocessor {
  ImageUploadPreprocessor._();

  static const _channel = MethodChannel(
    'com.barqwadih.app/image_upload_preprocessor',
  );

  static Future<XFile> prepare(XFile source) async {
    if (!Platform.isIOS) return source;

    final outputPath = await _channel.invokeMethod<String>('normalizeToJpeg', {
      'path': source.path,
      // The backend's largest stored ad variant is 1280px. Keeping a little
      // headroom preserves detail while avoiding multi-megabyte iPhone uploads.
      'maxDimension': 1440,
      'quality': 0.76,
    });

    if (outputPath == null || outputPath.isEmpty) {
      throw PlatformException(
        code: 'image_conversion_failed',
        message: 'تعذّر تجهيز الصورة للرفع.',
      );
    }

    return XFile(outputPath, mimeType: 'image/jpeg');
  }
}
