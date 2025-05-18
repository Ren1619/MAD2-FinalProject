import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppTheme {
  // Primary colors
  static final Color primaryColor = Colors.blue[700]!;
  static final Color primaryLightColor = Colors.blue[50]!;
  static final Color primaryDarkColor = Colors.blue[900]!;

  // Text colors
  static final Color textPrimary = Colors.grey[800]!;
  static final Color textSecondary = Colors.grey[600]!;

  // Background colors
  static final Color scaffoldBackground = Colors.grey[100]!;
  static final Color cardBackground = Colors.white;

  // Status colors
  static final Map<String, Color> statusColors = {
    'Active': Colors.green[700]!,
    'Inactive': Colors.red[700]!,
    'Pending': Colors.orange[700]!,
    'Approved': Colors.green[700]!,
    'For Revision': Colors.blue[700]!,
    'Denied': Colors.red[700]!,
    'Archived': Colors.grey[700]!,
  };

  // Card styles
  static final BorderRadius borderRadius = BorderRadius.circular(12);
  static final BoxShadow cardShadow = BoxShadow(
    color: Colors.black.withOpacity(0.05),
    blurRadius: 10,
    offset: const Offset(0, 4),
  );

  // Input decoration
  static InputDecoration inputDecoration({
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  // Button styles
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    elevation: 2,
  );

  static ButtonStyle outlineButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: primaryColor,
    side: BorderSide(color: primaryColor.withOpacity(0.5)),
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  // Text styles
  static const TextStyle headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle bodyLarge = TextStyle(fontSize: 16);

  static const TextStyle bodyMedium = TextStyle(fontSize: 14);

  static const TextStyle bodySmall = TextStyle(fontSize: 12);

  // App theme data
  static ThemeData lightTheme = ThemeData(
    primarySwatch: Colors.blue,
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: scaffoldBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: cardBackground,
      elevation: 0,
      iconTheme: IconThemeData(color: primaryColor),
      titleTextStyle: TextStyle(
        color: primaryColor,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: outlineButtonStyle),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardTheme(
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
    ),
  );
}
