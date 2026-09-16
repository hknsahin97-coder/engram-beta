import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Content shared from another app.
///
/// **Text only.** Sharing images is not supported yet.
@immutable
class IncomingShare {
  const IncomingShare(this.text);

  /// The shared text. Apps such as Chrome send the title and the link
  /// separately; the native side joins them on consecutive lines.
  final String text;

  @override
  bool operator ==(Object other) =>
      other is IncomingShare && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'IncomingShare($text)';
}

/// The channel carrying shares in from the native side.
///
/// **Why our own channel rather than a plugin:** the Kotlin needed for sharing
/// is about thirty lines -- cheaper than a native dependency, and the behaviour
/// is ours.
class ShareChannel {
  const ShareChannel([this.channel = const MethodChannel(name)]);

  static const String name = 'com.engram.engram/share';

  final MethodChannel channel;

  /// If the app **was opened by a share**, takes that share and consumes it on
  /// the native side. A second call returns `null` -- otherwise the app would
  /// replay the same share on every launch.
  Future<IncomingShare?> takeInitial() async {
    try {
      final text = await channel.invokeMethod<String>('takeInitialShare');
      return _wrap(text);
    } on MissingPluginException {
      // No channel on iOS or in tests; the share target is Android-only.
      return null;
    } catch (e) {
      debugPrint('Could not read the share: $e');
      return null;
    }
  }

  /// Listens for shares that arrive **while the app is open**.
  void listen(void Function(IncomingShare) onShare) {
    channel.setMethodCallHandler((call) async {
      if (call.method != 'onShare') return null;
      final share = _wrap(call.arguments as String?);
      if (share != null) onShare(share);
      return null;
    });
  }

  static IncomingShare? _wrap(String? text) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : IncomingShare(trimmed);
  }
}

final shareChannelProvider = Provider<ShareChannel>(
  (ref) => const ShareChannel(),
);

/// A share that has not yet been written into the capture field.
///
/// A single-use mailbox: the channel drops a share here, [TextPanel] picks it
/// up and empties it with [consume]. This state sits in between rather than
/// writing straight to the `TextEditingController`, because when a share
/// arrives there is no guarantee the panel has been built -- `PageView` only
/// creates the text page once it is nearby.
final incomingShareProvider =
    NotifierProvider<IncomingShareController, IncomingShare?>(
  IncomingShareController.new,
);

class IncomingShareController extends Notifier<IncomingShare?> {
  @override
  IncomingShare? build() => null;

  void receive(IncomingShare share) => state = share;

  /// Reads the share and empties the mailbox. `null` when empty.
  IncomingShare? consume() {
    final current = state;
    state = null;
    return current;
  }
}
