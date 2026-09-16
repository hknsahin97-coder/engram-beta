import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../l10n/app_localizations.dart';
import 'pdf_import_screen.dart';
import 'photo_confirm_screen.dart';
import 'video_confirm_screen.dart';

/// Import mode: recent photos and videos plus PDF selection.
///
/// ## Photos and video
/// Video items are marked with a play badge.
///
/// ## Permission
/// The camera has to remember its permission state; here that is
/// unnecessary: `photo_manager` can ask **without** asking
/// (`getPermissionState`). It is queried silently when the panel opens; without
/// permission a single button replaces the grid; the request goes out on a tap.
class ImportPanel extends ConsumerStatefulWidget {
  const ImportPanel({super.key, required this.isActive});

  final bool isActive;

  @override
  ConsumerState<ImportPanel> createState() => _ImportPanelState();
}

class _ImportPanelState extends ConsumerState<ImportPanel> {
  /// Items in the grid: four columns by two rows.
  ///
  /// Twelve does not fit: the third row would be cut in half by the drawer.
  /// Making it scrollable is not right either -- this is not a gallery but a
  /// quick shortcut to what was captured recently.
  static const int _recentCount = 8;

  List<AssetEntity>? _assets;
  bool _permissionAsked = false;
  bool _hasAccess = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _checkPermissionQuietly();
  }

  @override
  void didUpdateWidget(ImportPanel old) {
    super.didUpdateWidget(old);
    // Refreshed every time the panel becomes visible: the user may have taken a
    // photo in another app in between and expects to find it here.
    if (widget.isActive && !old.isActive) _checkPermissionQuietly();
  }

  static const _request = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.common,
      mediaLocation: false,
    ),
  );

  Future<void> _checkPermissionQuietly() async {
    final state = await PhotoManager.getPermissionState(
      requestOption: _request,
    );
    if (!mounted) return;
    setState(() => _hasAccess = state.hasAccess);
    if (state.hasAccess) _load();
  }

  Future<void> _requestPermission() async {
    setState(() => _permissionAsked = true);
    final state = await PhotoManager.requestPermissionExtend(
      requestOption: _request,
    );
    if (!mounted) return;
    setState(() => _hasAccess = state.hasAccess);
    if (state.hasAccess) _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        onlyAll: true,
      );
      final assets = albums.isEmpty
          ? <AssetEntity>[]
          : await albums.first.getAssetListRange(start: 0, end: _recentCount);
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Could not read the gallery: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null || !mounted) return;
    if (asset.type == AssetType.video) {
      await VideoConfirmScreen.open(context, file);
    } else {
      await PhotoConfirmScreen.open(context, file);
    }
  }

  @override
  Widget build(BuildContext context) {
    // No "swipe up for the gallery" hint: the drawer is always open, and text
    // suggesting you open an already-open drawer would promise a gesture that
    // does not exist.
    return Stack(
      children: [
        Align(
          alignment: Alignment.bottomCenter,
          child: _Drawer(
            child: _hasAccess
                ? _Grid(
                    assets: _assets,
                    loading: _loading,
                    onPick: _pick,
                    onPickPdf: _pickPdf,
                  )
                : _PermissionPrompt(
                    // If the first request was refused the system dialog never
                    // appears again; the text then has to point at the phone's
                    // settings, or the user keeps tapping for nothing.
                    denied: _permissionAsked,
                    onAllow: _requestPermission,
                    onPickPdf: _pickPdf,
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickPdf() => PdfImportScreen.pick(context);
}

/// The bottom drawer: 370px, dark, rounded on top.
class _Drawer extends StatelessWidget {
  const _Drawer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 370,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        0,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF161618),
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(AppRadius.hairline),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl - 2),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.assets,
    required this.loading,
    required this.onPick,
    required this.onPickPdf,
  });

  final List<AssetEntity>? assets;
  final bool loading;
  final ValueChanged<AssetEntity> onPick;
  final VoidCallback onPickPdf;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final list = assets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RowLabel(l10n.importRecent),
        Expanded(
          child: switch (list) {
            null => const SizedBox.shrink(),
            [] => Text(
                l10n.importNoPhotos,
                style: AppText.body(
                  size: 13,
                  color: ViewfinderColors.textSecondary,
                ),
              ),
            _ => GridView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: AppSpacing.xs,
                  crossAxisSpacing: AppSpacing.xs,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) => _Thumb(
                  // Identity key: when the list refreshes, Flutter should not
                  // rebuild the tile of the same photo.
                  key: ValueKey(list[i].id),
                  asset: list[i],
                  onTap: () => onPick(list[i]),
                ),
              ),
          },
        ),
        _PdfLink(onTap: onPickPdf),
      ],
    );
  }
}

/// A single thumbnail.
///
/// **It has to be stateful.** Building the `FutureBuilder` directly inside
/// `build` would start a new request on every repaint of the panel and
/// discard the previous result, leaving most tiles empty. The request is
/// started **once**, here.
class _Thumb extends StatefulWidget {
  const _Thumb({super.key, required this.asset, required this.onTap});

  final AssetEntity asset;
  final VoidCallback onTap;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  late final Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    // The thumbnail comes from the plugin; opening full-size files for a grid
    // would inflate memory needlessly across eight photos.
    _bytes = widget.asset.thumbnailDataWithSize(
      const ThumbnailSize.square(200),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          color: const Color(0xFF2A2D34),
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<Uint8List?>(
                future: _bytes,
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  if (bytes == null) return const SizedBox.shrink();
                  return Image.memory(bytes, fit: BoxFit.cover);
                },
              ),
              // The play badge is the only sign that this is a video; the
              // thumbnail looks just like a photo.
              if (widget.asset.type == AssetType.video)
                const Center(
                  child: Text(
                    '▶',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionPrompt extends StatelessWidget {
  const _PermissionPrompt({
    required this.denied,
    required this.onAllow,
    required this.onPickPdf,
  });

  final bool denied;
  final VoidCallback onAllow;
  final VoidCallback onPickPdf;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RowLabel(l10n.importRecent),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  denied ? l10n.permPhotosDenied : l10n.permPhotosBody,
                  textAlign: TextAlign.center,
                  style: AppText.body(
                    size: 13,
                    color: ViewfinderColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                InkWell(
                  onTap: onAllow,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.accent,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Text(
                      l10n.permAllow,
                      style: AppText.body(
                        size: 15,
                        weight: 600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // PDF needs no permission: it has to stay here even with the gallery
        // closed, or the mode dies entirely for a user who refuses permission.
        _PdfLink(onTap: onPickPdf),
      ],
    );
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
      child: Text(
        text,
        style: AppText.body(
          size: 12,
          weight: 600,
          color: Colors.white.withValues(alpha: 0.5),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PdfLink extends StatelessWidget {
  const _PdfLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          // Bottom padding for the floating islet, which would otherwise sit
          // on top of the PDF row.
          padding: const EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: 76,
          ),
          child: Row(
            children: [
              const Text('📄', style: TextStyle(fontSize: 15)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                L10n.of(context).importPickPdf,
                style: AppText.body(
                  size: 14,
                  weight: 500,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
