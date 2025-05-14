
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class ImageUtils {
  // Save image file to application documents directory
  static Future<String?> saveImage(File imageFile, String prefix) async {
    try {
      // Get application documents directory
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      String appDocPath = appDocDir.path;

      // Create unique filename
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String filename = '$prefix-$timestamp${extension(imageFile.path)}';

      // Create directory if it doesn't exist
      final Directory receiptDir = Directory('$appDocPath/receipts');
      if (!await receiptDir.exists()) {
        await receiptDir.create(recursive: true);
      }

      // Copy file to new location
      final String filePath = '${receiptDir.path}/$filename';
      await imageFile.copy(filePath);

      return filePath;
    } catch (e) {
      print('Error saving image: $e');
      return null;
    }
  }

  // Delete image file
  static Future<bool> deleteImage(String filePath) async {
    try {
      final File file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }
}
