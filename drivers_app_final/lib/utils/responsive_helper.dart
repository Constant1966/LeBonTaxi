import 'package:flutter/material.dart';

/// Utilitaire pour construire des interfaces adaptatives (mobile / tablette)
class ResponsiveHelper {
  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;

  // ============================================================
  // DÉTECTION TYPE D'APPAREIL
  // ============================================================

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  // ============================================================
  // DIMENSIONS
  // ============================================================

  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Padding horizontal adaptatif
  static double horizontalPadding(BuildContext context) {
    final width = screenWidth(context);
    if (width < mobileBreakpoint) return 16;
    if (width < tabletBreakpoint) return 32;
    return 48;
  }

  /// Largeur maximale du contenu (pour centrer sur tablette/desktop)
  static double contentMaxWidth(BuildContext context) {
    final width = screenWidth(context);
    if (width < mobileBreakpoint) return width;
    if (width < tabletBreakpoint) return 600;
    return 800;
  }

  /// Taille de police adaptative
  static double fontSize(BuildContext context, double base) {
    final width = screenWidth(context);
    if (width < mobileBreakpoint) return base;
    if (width < tabletBreakpoint) return base * 1.1;
    return base * 1.2;
  }

  /// Nombre de colonnes pour une grille
  static int gridColumns(BuildContext context) {
    final width = screenWidth(context);
    if (width < mobileBreakpoint) return 2;
    if (width < tabletBreakpoint) return 3;
    return 4;
  }

  // ============================================================
  // WIDGETS UTILITAIRES
  // ============================================================

  /// Construit un conteneur centré avec largeur max pour tablette
  static Widget centeredContent({
    required BuildContext context,
    required Widget child,
    double? maxWidth,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? contentMaxWidth(context),
        ),
        child: child,
      ),
    );
  }
}

/// Widget qui choisit entre un layout mobile et un layout tablette
class ResponsiveLayout extends StatelessWidget {
  final Widget mobileLayout;
  final Widget? tabletLayout;

  const ResponsiveLayout({
    super.key,
    required this.mobileLayout,
    this.tabletLayout,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isMobile(context)) {
      return mobileLayout;
    }
    return tabletLayout ?? mobileLayout;
  }
}
