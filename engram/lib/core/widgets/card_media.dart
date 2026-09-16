import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../media/media_store.dart';
import '../theme/tokens.dart';

/// Displays a card's media.
///
/// Because the paths in the database are **relative** (see the [MediaStore]
/// documentation), the file is resolved on every read; no widget ever stores
/// an absolute path.
///
/// [preferThumbnail] is for small surfaces: there is no point holding twenty
/// full-resolution photos in memory for the Library grid. Thumbnail generation
/// may have failed (it is a convenience, not a guarantee) -- in that case this
/// falls back to the full-size file.
class CardMedia extends ConsumerWidget {
  const CardMedia({
    super.key,
    required this.mediaPath,
    this.thumbnailPath,
    this.preferThumbnail = false,
    this.fit = BoxFit.cover,
  });

  final String? mediaPath;
  final String? thumbnailPath;
  final bool preferThumbnail;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rel = preferThumbnail ? (thumbnailPath ?? mediaPath) : mediaPath;
    if (rel == null) return const _MissingMedia();

    final file = ref.watch(mediaStoreProvider).resolve(rel);
    if (!file.existsSync()) return const _MissingMedia();

    return Image.file(
      file,
      fit: fit,
      // A corrupt file must not stop the card from opening: a red error box in
      // the middle of a review session is far worse than a missing image.
      errorBuilder: (_, __, ___) => const _MissingMedia(),
    );
  }
}

/// The file was deleted or cannot be read. Instead of leaving it silently
/// blank, a calm surface that says what happened -- the user should understand
/// the card is broken without being scolded by an error message.
class _MissingMedia extends StatelessWidget {
  const _MissingMedia();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.palette.background,
      child: const Center(
        child: Text('🖼️', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
