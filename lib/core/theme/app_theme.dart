import 'package:flutter/material.dart';
import '../design_system/tokens/color_tokens.dart';
import '../design_system/tokens/typography_tokens.dart';
import '../design_system/tokens/spacing_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: AppColors.brandPrimary600,
          onPrimary: AppColors.surface,
          primaryContainer: AppColors.brandPrimary100,
          onPrimaryContainer: AppColors.brandPrimary800,
          secondary: AppColors.secondaryBlue600,
          onSecondary: AppColors.surface,
          secondaryContainer: AppColors.brandPrimary100,
          onSecondaryContainer: AppColors.brandPrimary800,
          tertiary: AppColors.secondarySky500,
          onTertiary: AppColors.neutral900,
          error: AppColors.danger600,
          onError: AppColors.surface,
          surface: AppColors.surface,
          onSurface: AppColors.neutral900,
          surfaceContainerLow: Color(0xFFFFFFFF),
          surfaceContainer: Color(0xFFF0F7FF),
          surfaceContainerHigh: Color(0xFFE6F0FB),
          surfaceContainerHighest: AppColors.neutral100,
          onSurfaceVariant: AppColors.neutral700,
          outline: AppColors.neutral500,
          outlineVariant: AppColors.neutral100,
          shadow: Colors.black,
          scrim: Colors.black54,
          inverseSurface: AppColors.neutral900,
          onInverseSurface: AppColors.surface,
          inversePrimary: AppColors.brandPrimary100,
        ),
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: AppTypography.fontNunito,

        // AppBar
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.neutral900,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: AppTypography.headingMedium.copyWith(
            color: AppColors.neutral900,
          ),
          iconTheme: const IconThemeData(color: AppColors.neutral700),
          surfaceTintColor: Colors.transparent,
        ),

        // Card
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: AppElevation.low,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),

        // ElevatedButton
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandPrimary600,
            foregroundColor: AppColors.surface,
            elevation: 0,
            minimumSize: const Size(double.infinity, 52),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            textStyle: AppTypography.buttonLarge,
          ),
        ),

        // OutlinedButton
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.brandPrimary600,
            minimumSize: const Size(double.infinity, 52),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            side: const BorderSide(color: AppColors.brandPrimary600, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            textStyle: AppTypography.buttonLarge,
          ),
        ),

        // TextButton
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brandPrimary600,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            textStyle: AppTypography.buttonMedium,
          ),
        ),

        // InputDecoration
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: AppColors.neutral500),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: AppColors.neutral100, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: AppColors.brandPrimary600, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: AppColors.danger600, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: AppColors.danger600, width: 2),
          ),
          labelStyle: AppTypography.labelLarge.copyWith(color: AppColors.neutral500),
          hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.neutral500),
          errorStyle: AppTypography.labelSmall.copyWith(color: AppColors.danger600),
        ),

        // Chips
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.neutral100,
          selectedColor: AppColors.brandPrimary100,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          labelStyle: AppTypography.labelMedium,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
        ),

        // Divider
        dividerTheme: const DividerThemeData(
          color: AppColors.neutral100,
          thickness: 1,
          space: 0,
        ),

        // BottomNavigation
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.brandPrimary100,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.brandPrimary600, size: 24);
            }
            return const IconThemeData(color: AppColors.neutral500, size: 24);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppTypography.labelSmall.copyWith(
                color: AppColors.brandPrimary600,
                fontWeight: FontWeight.w600,
              );
            }
            return AppTypography.labelSmall.copyWith(color: AppColors.neutral500);
          }),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),

        // FAB
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.brandPrimary600,
          foregroundColor: AppColors.surface,
          elevation: AppElevation.medium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),

        // SnackBar
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.neutral900,
          contentTextStyle: AppTypography.bodyMedium.copyWith(
            color: AppColors.surface,
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),

        // Dialog
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surface,
          elevation: AppElevation.high,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.modal),
          ),
          titleTextStyle: AppTypography.headingMedium.copyWith(
            color: AppColors.neutral900,
          ),
          contentTextStyle: AppTypography.bodyMedium.copyWith(
            color: AppColors.neutral700,
          ),
        ),

        // BottomSheet
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.modal),
            ),
          ),
          elevation: AppElevation.high,
        ),

        // ListTile
        listTileTheme: ListTileThemeData(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          titleTextStyle: AppTypography.bodyLarge.copyWith(
            color: AppColors.neutral900,
          ),
          subtitleTextStyle: AppTypography.bodySmall.copyWith(
            color: AppColors.neutral500,
          ),
        ),

        // Progress indicator
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.brandPrimary600,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: AppColors.brandPrimary500,
          onPrimary: AppColors.surface,
          primaryContainer: Color(0xFF173D63),
          onPrimaryContainer: AppColors.brandPrimary100,
          secondary: AppColors.secondarySky500,
          onSecondary: AppColors.neutral900,
          secondaryContainer: Color(0xFF0F2942),
          onSecondaryContainer: Color(0xFFBCE7FF),
          tertiary: AppColors.secondaryBlue600,
          onTertiary: AppColors.surface,
          error: AppColors.danger600,
          onError: AppColors.surface,
          surface: Color(0xFF0D1526),
          onSurface: Color(0xFFE5E7EB),
          surfaceContainerLow: Color(0xFF1A2540),
          surfaceContainer: Color(0xFF1E2D4A),
          surfaceContainerHigh: Color(0xFF243352),
          surfaceContainerHighest: Color(0xFF1F2937),
          onSurfaceVariant: Color(0xFFD1D5DB),
          outline: Color(0xFF4B5563),
          outlineVariant: Color(0xFF374151),
          shadow: Colors.black,
          scrim: Colors.black87,
          inverseSurface: AppColors.surface,
          onInverseSurface: AppColors.neutral900,
          inversePrimary: AppColors.brandPrimary800,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1220),
        fontFamily: AppTypography.fontNunito,
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: const Color(0xFFE5E7EB),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: AppTypography.headingMedium.copyWith(
            color: const Color(0xFFE5E7EB),
          ),
          iconTheme: const IconThemeData(color: Color(0xFFD1D5DB)),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF111827),
          elevation: AppElevation.low,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF111827),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: Color(0xFF4B5563)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: Color(0xFF374151), width: 1.3),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: AppColors.secondarySky500, width: 2),
          ),
          labelStyle: AppTypography.labelLarge.copyWith(color: const Color(0xFF9CA3AF)),
          hintStyle: AppTypography.bodyMedium.copyWith(color: const Color(0xFF9CA3AF)),
          errorStyle: AppTypography.labelSmall.copyWith(color: AppColors.danger600),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF374151),
          thickness: 1,
          space: 0,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.secondarySky500,
        ),

        // ElevatedButton
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandPrimary500,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF1F2937),
            disabledForegroundColor: const Color(0xFF6B7280),
            elevation: 0,
            minimumSize: const Size(double.infinity, 52),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            textStyle: AppTypography.buttonLarge,
          ),
        ),

        // OutlinedButton
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.secondarySky500,
            minimumSize: const Size(double.infinity, 52),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            side: const BorderSide(color: AppColors.secondarySky500, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            textStyle: AppTypography.buttonLarge,
          ),
        ),

        // TextButton
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.secondarySky500,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            textStyle: AppTypography.buttonMedium,
          ),
        ),

        // Chips
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF1F2937),
          selectedColor: const Color(0xFF173D63),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          labelStyle: AppTypography.labelMedium.copyWith(
            color: const Color(0xFFE5E7EB),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
        ),

        // BottomNavigation
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0F172A),
          indicatorColor: const Color(0xFF173D63),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.secondarySky500, size: 24);
            }
            return const IconThemeData(color: Color(0xFF6B7280), size: 24);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppTypography.labelSmall.copyWith(
                color: AppColors.secondarySky500,
                fontWeight: FontWeight.w600,
              );
            }
            return AppTypography.labelSmall.copyWith(
              color: const Color(0xFF6B7280),
            );
          }),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),

        // FAB
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.brandPrimary500,
          foregroundColor: Colors.white,
          elevation: AppElevation.medium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),

        // SnackBar
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1F2937),
          contentTextStyle: AppTypography.bodyMedium.copyWith(
            color: const Color(0xFFE5E7EB),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),

        // Dialog
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF111827),
          elevation: AppElevation.high,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.modal),
          ),
          titleTextStyle: AppTypography.headingMedium.copyWith(
            color: const Color(0xFFE5E7EB),
          ),
          contentTextStyle: AppTypography.bodyMedium.copyWith(
            color: const Color(0xFFD1D5DB),
          ),
        ),

        // BottomSheet
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF111827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.modal),
            ),
          ),
          elevation: AppElevation.high,
        ),

        // ListTile
        listTileTheme: ListTileThemeData(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          titleTextStyle: AppTypography.bodyLarge.copyWith(
            color: const Color(0xFFE5E7EB),
          ),
          subtitleTextStyle: AppTypography.bodySmall.copyWith(
            color: const Color(0xFF9CA3AF),
          ),
        ),
      );
}
