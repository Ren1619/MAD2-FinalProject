import 'dart:math';

class UuidGenerator {
  static String generateUuid() {
    const String chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final Random random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        20, 
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }
}