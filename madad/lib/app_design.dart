import 'package:flutter/material.dart';

class AppDesign {
  AppDesign._();

  static const Color primary = Color(0xFF0A4D5C);
  static const Color secondary = Color(0xFF8AA7B0);
  static const Color softGreen = Color(0xFF8AA495);

  static const Color background = Color.fromARGB(255, 242, 247, 248);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF7FAFB);
  static const Color border = Color(0xFFE3EAEC);

  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF5F6B70);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  static const Color error = Color.fromARGB(255, 80, 53, 53);

  static const Color success = Color.fromARGB(255, 36, 63, 37);
  static const Color warning = Color.fromARGB(255, 248, 219, 173);

  static const String fontFamily = 'Tajawal';
  static const double lineHeight = 1.3;

  static const double h1 = 24;
  static const double h2 = 20;
  static const double subtitle = 16;
  static const double body = 14;
  static const double button = 16;
  static const double caption = 12;

  static const double radiusXS = 8;
  static const double radiusSM = 12;
  static const double radiusMD = 16;
  static const double radiusLG = 20;
  static const double radiusXL = 24;

  static const double spaceXS = 4;
  static const double spaceSM = 8;
  static const double spaceMD = 12;
  static const double spaceLG = 16;
  static const double spaceXL = 20;
  static const double space2XL = 24;

  static const double screenPadding = 16;
  static const double sectionSpacing = 24;

  static const double buttonHeightSM = 44;
  static const double buttonHeightMD = 52;
  static const double buttonHeightLG = 56;

  static const double inputHeight = 56;
  static const double inputHorizontalPadding = 16;
  static const double inputVerticalPadding = 16;

  static const double cardRadius = 20;
  static const double cardPadding = 16;
  static const double cardMinHeightSM = 100;
  static const double cardMinHeightMD = 140;
  static const double cardMinHeightLG = 180;

  static const double iconSM = 18;
  static const double iconMD = 24;
  static const double iconLG = 32;

  static const double cardElevation = 1;
  static const double fabElevation = 2;

  static const TextStyle h1Style = TextStyle(
    fontFamily: fontFamily,
    fontSize: h1,
    fontWeight: FontWeight.bold,
    height: lineHeight,
    color: textPrimary,
  );

  static const TextStyle h2Style = TextStyle(
    fontFamily: fontFamily,
    fontSize: h2,
    fontWeight: FontWeight.w600,
    height: lineHeight,
    color: textPrimary,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: subtitle,
    fontWeight: FontWeight.w500,
    height: lineHeight,
    color: textPrimary,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: body,
    fontWeight: FontWeight.w400,
    height: lineHeight,
    color: textPrimary,
  );

  static const TextStyle bodySecondaryStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: body,
    fontWeight: FontWeight.w400,
    height: lineHeight,
    color: textSecondary,
  );

  static const TextStyle buttonOnPrimaryStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: button,
    fontWeight: FontWeight.w600,
    height: lineHeight,
    color: white,
  );

  static const TextStyle buttonPrimaryTextStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: button,
    fontWeight: FontWeight.w600,
    height: lineHeight,
    color: primary,
  );

  static const TextStyle captionStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: caption,
    fontWeight: FontWeight.w400,
    height: lineHeight,
    color: textSecondary,
  );

  static final BoxDecoration primaryCardDecoration = BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(cardRadius),
    border: Border.all(color: border),
    boxShadow: [
      BoxShadow(
        color: black.withOpacity(0.04),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static final BoxDecoration softCardDecoration = BoxDecoration(
    color: surfaceAlt,
    borderRadius: BorderRadius.circular(cardRadius),
    border: Border.all(color: border),
  );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: background,
    brightness: Brightness.light,

    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: const Color.fromARGB(255, 100, 151, 156),
      surface: surface,
      error: error,
      brightness: Brightness.light,
    ),

    textTheme: const TextTheme(
      headlineLarge: h1Style,
      headlineMedium: h2Style,
      titleMedium: subtitleStyle,
      bodyLarge: bodyStyle,
      bodyMedium: bodyStyle,
      bodySmall: captionStyle,
      labelLarge: buttonOnPrimaryStyle,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: h2,
        fontWeight: FontWeight.w600,
        height: lineHeight,
        color: textPrimary,
      ),
      iconTheme: IconThemeData(color: textPrimary, size: iconMD),
    ),

    cardTheme: CardThemeData(
      color: surface,
      elevation: cardElevation,
      shadowColor: black.withOpacity(0.04),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: const BorderSide(color: border),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: white,
        elevation: 0,
        minimumSize: const Size(double.infinity, buttonHeightMD),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLG),
        ),
        textStyle: buttonOnPrimaryStyle,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        minimumSize: const Size(double.infinity, buttonHeightMD),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: const BorderSide(color: primary, width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLG),
        ),
        textStyle: buttonPrimaryTextStyle,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: body,
          fontWeight: FontWeight.w600,
          height: lineHeight,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: inputHorizontalPadding,
        vertical: inputVerticalPadding,
      ),
      hintStyle: const TextStyle(
        fontFamily: fontFamily,
        fontSize: body,
        fontWeight: FontWeight.w400,
        height: lineHeight,
        color: textSecondary,
      ),
      labelStyle: const TextStyle(
        fontFamily: fontFamily,
        fontSize: body,
        fontWeight: FontWeight.w500,
        height: lineHeight,
        color: textSecondary,
      ),
      errorStyle: const TextStyle(
        fontFamily: fontFamily,
        fontSize: caption,
        fontWeight: FontWeight.w400,
        color: error,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusLG),
        borderSide: const BorderSide(color: border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusLG),
        borderSide: const BorderSide(color: border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusLG),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusLG),
        borderSide: const BorderSide(color: error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusLG),
        borderSide: const BorderSide(color: error, width: 1.5),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: primary,
      contentTextStyle: const TextStyle(
        fontFamily: fontFamily,
        fontSize: body,
        fontWeight: FontWeight.w500,
        height: lineHeight,
        color: white,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMD),
      ),
    ),

    dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),

    iconTheme: const IconThemeData(color: primary, size: iconMD),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: white,
      elevation: fabElevation,
    ),

    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusXS),
      ),
      side: const BorderSide(color: border),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: softGreen.withOpacity(0.12),
      disabledColor: border,
      selectedColor: primary,
      secondarySelectedColor: primary,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      labelStyle: const TextStyle(
        fontFamily: fontFamily,
        fontSize: caption,
        fontWeight: FontWeight.w500,
        height: lineHeight,
        color: textPrimary,
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: fontFamily,
        fontSize: caption,
        fontWeight: FontWeight.w500,
        height: lineHeight,
        color: white,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );

  static Future<bool> showAppDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'نعم',
    String cancelText = 'إلغاء',
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: const Color(0xFFF7FAFB),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: AppDesign.fontFamily,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        softWrap: true,
                        style: const TextStyle(
                          fontFamily: AppDesign.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(
                    cancelText,
                    style: const TextStyle(
                      fontFamily: AppDesign.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(
                    confirmText,
                    style: const TextStyle(
                      fontFamily: AppDesign.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  static void showSuccessSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(message, textAlign: TextAlign.right),
        ),
        duration: duration,
        backgroundColor: success,
        behavior: SnackBarBehavior.floating,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 70),
      ),
    );
  }

  static void showErrorSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(message, textAlign: TextAlign.right),
        ),
        duration: duration,
        backgroundColor: primary,
        behavior: SnackBarBehavior.floating,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

        margin: const EdgeInsets.fromLTRB(16, 16, 16, 70),
      ),
    );
  }

  static void showImageValidSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,

        backgroundColor: Colors.green.shade700,

        behavior: SnackBarBehavior.floating,

        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

        margin: const EdgeInsets.fromLTRB(16, 16, 16, 70),
      ),
    );
  }

  static void showImageInvalidSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(message, textAlign: TextAlign.right),
        ),
        duration: duration,

        backgroundColor: Colors.red.shade700,

        behavior: SnackBarBehavior.floating,

        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

        margin: const EdgeInsets.fromLTRB(16, 16, 16, 70),
      ),
    );
  }
}

class AppGap {
  AppGap._();

  static const SizedBox xs = SizedBox(height: AppDesign.spaceXS);
  static const SizedBox sm = SizedBox(height: AppDesign.spaceSM);
  static const SizedBox md = SizedBox(height: AppDesign.spaceMD);
  static const SizedBox lg = SizedBox(height: AppDesign.spaceLG);
  static const SizedBox xl = SizedBox(height: AppDesign.spaceXL);
  static const SizedBox xxl = SizedBox(height: AppDesign.space2XL);
  static const SizedBox section = SizedBox(height: AppDesign.sectionSpacing);

  static const SizedBox wXS = SizedBox(width: AppDesign.spaceXS);
  static const SizedBox wSM = SizedBox(width: AppDesign.spaceSM);
  static const SizedBox wMD = SizedBox(width: AppDesign.spaceMD);
  static const SizedBox wLG = SizedBox(width: AppDesign.spaceLG);
  static const SizedBox wXL = SizedBox(width: AppDesign.spaceXL);
}

class AppPadding {
  AppPadding._();

  static const EdgeInsets screen = EdgeInsets.all(AppDesign.screenPadding);
  static const EdgeInsets card = EdgeInsets.all(AppDesign.cardPadding);

  static const EdgeInsets horizontal = EdgeInsets.symmetric(
    horizontal: AppDesign.screenPadding,
  );

  static const EdgeInsets vertical = EdgeInsets.symmetric(
    vertical: AppDesign.screenPadding,
  );

  static const EdgeInsets button = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 14,
  );
}

class AppSizes {
  AppSizes._();

  static const double buttonHeight = AppDesign.buttonHeightMD;
  static const double inputHeight = AppDesign.inputHeight;

  static const double cardSmall = AppDesign.cardMinHeightSM;
  static const double cardMedium = AppDesign.cardMinHeightMD;
  static const double cardLarge = AppDesign.cardMinHeightLG;

  static const double iconSmall = AppDesign.iconSM;
  static const double iconMedium = AppDesign.iconMD;
  static const double iconLarge = AppDesign.iconLG;
}
