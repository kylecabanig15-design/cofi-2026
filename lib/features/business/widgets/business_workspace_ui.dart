import 'package:flutter/material.dart';

/// Shared visual language for every screen opened from My Business.
///
/// The palette deliberately leans into espresso, paper and copper tones so the
/// owner experience feels related to CoFi without looking like a generic admin
/// dashboard.
abstract final class BusinessWorkspaceColors {
  static const canvas = Color(0xFF0B0A09);
  static const surface = Color(0xFF171512);
  static const surfaceRaised = Color(0xFF211E19);
  static const paper = Color(0xFFFFFFFF);
  static const muted = Color(0xFFAAAAAA);
  static const copper = Color(0xFFD87954);
  static const moss = Color(0xFF8FAE79);
  static const action = Color(0xFF9F2632);
  static const line = Color(0xFF332E28);

  /// Keeps primary actions in the destination's accent family while making
  /// the fill dark enough for accessible white labels and progress spinners.
  static Color actionFill(Color accent) {
    var fill = accent;
    while (fill.computeLuminance() > .18) {
      fill = Color.alphaBlend(const Color(0x1A000000), fill);
    }
    return fill;
  }
}

/// Applies the same interaction language to every owner screen—not just the
/// same colors. Buttons, fields, menus, radios and cards all inherit these
/// dimensions and states.
class BusinessWorkspaceTheme extends StatelessWidget {
  const BusinessWorkspaceTheme({
    super.key,
    required this.child,
    this.accentColor,
  });

  final Widget child;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final accent = accentColor ?? BusinessWorkspaceColors.copper;
    final actionFill = BusinessWorkspaceColors.actionFill(accent);
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: BusinessWorkspaceColors.surface,
    ).copyWith(
      primary: actionFill,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.black,
      surface: BusinessWorkspaceColors.surface,
      onSurface: Colors.white,
      outline: BusinessWorkspaceColors.line,
    );

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: BusinessWorkspaceColors.line),
    );

    return Theme(
      data: base.copyWith(
        colorScheme: scheme,
        scaffoldBackgroundColor: BusinessWorkspaceColors.canvas,
        canvasColor: BusinessWorkspaceColors.canvas,
        cardColor: BusinessWorkspaceColors.surface,
        dividerColor: BusinessWorkspaceColors.line,
        splashColor: Colors.white.withValues(alpha: .06),
        highlightColor: Colors.white.withValues(alpha: .03),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: BusinessWorkspaceColors.surface,
          labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: fieldBorder,
          enabledBorder: fieldBorder,
          focusedBorder: fieldBorder.copyWith(
            borderSide: BorderSide(color: accent, width: 1.4),
          ),
          errorBorder: fieldBorder.copyWith(
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: fieldBorder.copyWith(
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: actionFill,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.white12,
            disabledForegroundColor: Colors.white38,
            minimumSize: const Size(48, 52),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: actionFill,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(48, 52),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 52),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            side: const BorderSide(color: BusinessWorkspaceColors.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: accent,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        cardTheme: CardThemeData(
          color: BusinessWorkspaceColors.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: BusinessWorkspaceColors.line),
          ),
        ),
        listTileTheme: ListTileThemeData(
          textColor: Colors.white,
          iconColor: Colors.white70,
          selectedColor: accent,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
      ),
      child: child,
    );
  }
}

class BusinessSectionLabel extends StatelessWidget {
  const BusinessSectionLabel({
    super.key,
    required this.title,
    required this.description,
    required this.step,
  });

  final String title;
  final String description;
  final String step;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              step,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BusinessMetricsStrip extends StatelessWidget {
  const BusinessMetricsStrip({super.key, required this.items});

  final List<BusinessMetricData> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: BusinessWorkspaceColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BusinessWorkspaceColors.line),
      ),
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0)
              const SizedBox(
                height: 38,
                child: VerticalDivider(
                    width: 1, color: BusinessWorkspaceColors.line),
              ),
            Expanded(child: _BusinessMetric(item: items[index])),
          ],
        ],
      ),
    );
  }
}

class BusinessMetricData {
  const BusinessMetricData(this.value, this.label, {this.color});

  final String value;
  final String label;
  final Color? color;
}

class _BusinessMetric extends StatelessWidget {
  const _BusinessMetric({required this.item});

  final BusinessMetricData item;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.value,
          maxLines: 1,
          style: TextStyle(
            color: item.color ?? Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}

class BusinessSheetShell extends StatelessWidget {
  const BusinessSheetShell({
    super.key,
    required this.child,
    this.heightFactor = .9,
    this.accentColor,
  });

  final Widget child;
  final double heightFactor;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * heightFactor,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: BusinessWorkspaceColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: BusinessWorkspaceColors.line)),
      ),
      child: BusinessWorkspaceTheme(
        accentColor: accentColor,
        child: SafeArea(top: false, child: child),
      ),
    );
  }
}

class BusinessSheetHeader extends StatelessWidget {
  const BusinessSheetHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.action,
    this.showClose = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? action;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    return Column(
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 18),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: accent.withValues(alpha: .28),
                  ),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: BusinessWorkspaceColors.paper,
                        fontSize: 21,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BusinessWorkspaceColors.muted,
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null) action!,
              if (showClose)
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white60, size: 22),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: BusinessWorkspaceColors.line),
      ],
    );
  }
}

class BusinessPageIntro extends StatelessWidget {
  const BusinessPageIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BusinessWorkspaceColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BusinessWorkspaceColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: accent, size: 23),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: const TextStyle(
                    color: BusinessWorkspaceColors.paper,
                    fontSize: 23,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  description,
                  style: const TextStyle(
                    color: BusinessWorkspaceColors.muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class BusinessEmptyState extends StatelessWidget {
  const BusinessEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
          decoration: BoxDecoration(
            color: BusinessWorkspaceColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BusinessWorkspaceColors.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 27),
              ),
              const SizedBox(height: 17),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BusinessWorkspaceColors.paper,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BusinessWorkspaceColors.muted,
                  height: 1.35,
                  fontSize: 13,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: 20),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
