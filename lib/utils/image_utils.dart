import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class ImageUtils {
  // Convert image file to base64 string for Firebase storage
  static Future<String?> imageToBase64String(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      print('Error converting image to base64: $e');
      return null;
    }
  }

  // Convert base64 string back to image bytes
  static Uint8List? base64StringToImage(String base64String) {
    try {
      return base64Decode(base64String);
    } catch (e) {
      print('Error converting base64 to image: $e');
      return null;
    }
  }

  // Validate image file
  static bool isValidImageFile(File file) {
    try {
      final extension = file.path.split('.').last.toLowerCase();
      final validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
      return validExtensions.contains(extension);
    } catch (e) {
      print('Error validating image file: $e');
      return false;
    }
  }

  // Get file size in MB
  static Future<double> getFileSizeInMB(File file) async {
    try {
      final bytes = await file.length();
      return bytes / (1024 * 1024);
    } catch (e) {
      print('Error getting file size: $e');
      return 0.0;
    }
  }

  // Compress image if it's too large (basic implementation)
  static Future<String?> compressAndConvertToBase64(
    File imageFile, {
    double maxSizeMB = 5.0,
    int quality = 85,
  }) async {
    try {
      // Check file size
      final sizeMB = await getFileSizeInMB(imageFile);

      if (sizeMB > maxSizeMB) {
        // For now, just reject files that are too large
        // In a real implementation, you'd use image compression packages
        throw 'Image file is too large (${sizeMB.toStringAsFixed(1)}MB). Maximum allowed size is ${maxSizeMB}MB.';
      }

      // Validate file type
      if (!isValidImageFile(imageFile)) {
        throw 'Invalid image file format. Please use JPG, PNG, or other supported formats.';
      }

      // Convert to base64
      return await imageToBase64String(imageFile);
    } catch (e) {
      print('Error compressing image: $e');
      rethrow;
    }
  }

  // Get image mime type from base64 string
  static String? getImageMimeType(String base64String) {
    try {
      // Basic detection based on base64 header
      if (base64String.startsWith('/9j/')) {
        return 'image/jpeg';
      } else if (base64String.startsWith('iVBORw0KGgo')) {
        return 'image/png';
      } else if (base64String.startsWith('R0lGODlh') ||
          base64String.startsWith('R0lGODdh')) {
        return 'image/gif';
      } else if (base64String.startsWith('Qk0')) {
        return 'image/bmp';
      } else if (base64String.startsWith('UklGR')) {
        return 'image/webp';
      }
      return 'image/jpeg'; // Default fallback
    } catch (e) {
      print('Error detecting mime type: $e');
      return 'image/jpeg';
    }
  }

  // Create data URL for web display
  static String createDataUrl(String base64String) {
    final mimeType = getImageMimeType(base64String) ?? 'image/jpeg';
    return 'data:$mimeType;base64,$base64String';
  }

  // Validate and process receipt image
  static Future<Map<String, dynamic>> processReceiptImage(
    File imageFile,
  ) async {
    try {
      // Validate file
      if (!isValidImageFile(imageFile)) {
        throw 'Please select a valid image file (JPG, PNG, etc.)';
      }

      // Check file size
      final sizeMB = await getFileSizeInMB(imageFile);
      if (sizeMB > 10.0) {
        // 10MB limit for receipts
        throw 'Receipt image is too large (${sizeMB.toStringAsFixed(1)}MB). Please use an image smaller than 10MB.';
      }

      // Convert to base64
      final base64String = await compressAndConvertToBase64(
        imageFile,
        maxSizeMB: 10.0,
        quality: 85,
      );

      if (base64String == null) {
        throw 'Failed to process the image. Please try again.';
      }

      return {
        'success': true,
        'base64': base64String,
        'mimeType': getImageMimeType(base64String),
        'sizeKB':
            (base64String.length * 0.75 / 1024)
                .round(), // Approximate size in KB
        'originalSizeMB': sizeMB,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Generate thumbnail from base64 (simplified version)
  static String? generateThumbnail(String base64String, {int maxWidth = 200}) {
    // For a simple implementation, we'll just return the original
    // In a real app, you'd use image processing libraries to create actual thumbnails
    return base64String;
  }

  // Save base64 image to file (for debugging/testing)
  static Future<File?> saveBase64ToFile(
    String base64String,
    String fileName,
    String directory,
  ) async {
    try {
      if (kIsWeb) {
        // Cannot save files directly on web
        return null;
      }

      final bytes = base64StringToImage(base64String);
      if (bytes == null) return null;

      final file = File('$directory/$fileName');
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      print('Error saving base64 to file: $e');
      return null;
    }
  }

  // Extract metadata from image (basic implementation)
  static Map<String, dynamic> extractImageMetadata(File imageFile) {
    try {
      final fileName = imageFile.path.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();
      final lastModified = imageFile.lastModifiedSync();

      return {
        'fileName': fileName,
        'extension': extension,
        'lastModified': lastModified.toIso8601String(),
        'path': imageFile.path,
      };
    } catch (e) {
      print('Error extracting metadata: $e');
      return {};
    }
  }

  // Validate image for expense receipt
  static String? validateReceiptImage(File imageFile) {
    try {
      // Check if file exists
      if (!imageFile.existsSync()) {
        return 'Image file does not exist';
      }

      // Check file type
      if (!isValidImageFile(imageFile)) {
        return 'Invalid image format. Please use JPG, PNG, or other supported formats.';
      }

      // Check file size (async operation, so we'll do a basic check)
      final stat = imageFile.statSync();
      final sizeMB = stat.size / (1024 * 1024);
      if (sizeMB > 10.0) {
        return 'Image file is too large (${sizeMB.toStringAsFixed(1)}MB). Maximum size is 10MB.';
      }

      return null; // No errors
    } catch (e) {
      print('Error validating receipt image: $e');
      return 'Error validating image: ${e.toString()}';
    }
  }

  // Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  // Clean up temporary image files
  static Future<void> cleanupTempImages(List<File> tempFiles) async {
    for (final file in tempFiles) {
      try {
        if (file.existsSync()) {
          await file.delete();
        }
      } catch (e) {
        print('Error deleting temp file ${file.path}: $e');
      }
    }
  }

  // Create a placeholder base64 image (useful for testing)
  static String getPlaceholderImageBase64() {
    // A minimal 1x1 transparent PNG in base64
    return 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==';
  }

  // Utility to create image preview widget data
  static Map<String, dynamic> createImagePreviewData(String base64String) {
    return {
      'dataUrl': createDataUrl(base64String),
      'mimeType': getImageMimeType(base64String),
      'sizeKB': (base64String.length * 0.75 / 1024).round(),
      'isValid': base64String.isNotEmpty,
    };
  }
}

// Extension methods for easier use
extension FileImageUtils on File {
  Future<String?> toBase64() => ImageUtils.imageToBase64String(this);

  bool get isValidImage => ImageUtils.isValidImageFile(this);

  Future<double> get sizeInMB => ImageUtils.getFileSizeInMB(this);

  String? get validationError => ImageUtils.validateReceiptImage(this);

  Map<String, dynamic> get metadata => ImageUtils.extractImageMetadata(this);

  Future<Map<String, dynamic>> processAsReceipt() =>
      ImageUtils.processReceiptImage(this);
}

extension StringImageUtils on String {
  Uint8List? toImageBytes() => ImageUtils.base64StringToImage(this);

  String? get imageMimeType => ImageUtils.getImageMimeType(this);

  String get asDataUrl => ImageUtils.createDataUrl(this);

  Map<String, dynamic> get imagePreviewData =>
      ImageUtils.createImagePreviewData(this);
}
