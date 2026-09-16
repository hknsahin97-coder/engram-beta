import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The shared skeleton for bottom sheets: a surface rounded at the top, a grab
/// handle and a content area.
///
/// Library detail and Settings are built on top of this.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.child,
    this.showHandle = true,
    this.padding = const EdgeInsets.fromLTRB(22, 10, 22, 28),
  });

  final Widget child;

  /// The handle is the only sign that the sheet can be dragged.
  final bool showHandle;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHandle) ...[
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(AppRadius.hairline),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }

  /// A ready-made wrapper for `showModalBottomSheet` -- so the same
  /// `backgroundColor: transparent` plus `isScrollControlled` setup does not
  /// have to be repeated at every call site.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: isScrollControlled,
      builder: (_) => SheetScaffold(child: child),
    );
  }
}
