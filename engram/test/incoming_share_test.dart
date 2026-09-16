import 'package:engram/core/share/incoming_share.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(ShareChannel.name);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('ShareChannel', () {
    test('takes the share from the native side', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'takeInitialShare');
        return 'A title\nhttps://example.com';
      });

      final share = await const ShareChannel(channel).takeInitial();
      expect(share, const IncomingShare('A title\nhttps://example.com'));
    });

    test('an empty or whitespace-only share is ignored', () async {
      // A capture screen opened with empty text would produce a card that says
      // nothing to the user.
      for (final raw in [null, '', '   \n  ']) {
        messenger.setMockMethodCallHandler(channel, (_) async => raw);
        expect(await const ShareChannel(channel).takeInitial(), isNull);
      }
    });

    test('with no channel (iOS, test environment) it returns null quietly', () async {
      // The target is Android-specific. A missing channel is not an error
      // and must not break launch.
      messenger.setMockMethodCallHandler(channel, null);
      expect(await const ShareChannel(channel).takeInitial(), isNull);
    });

    test('a share arriving while the app is open reaches the listener', () async {
      final received = <IncomingShare>[];
      const ShareChannel(channel).listen(received.add);

      await messenger.handlePlatformMessage(
        ShareChannel.name,
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('onShare', '  A note  ')),
        (_) {},
      );

      // Surrounding whitespace has to be stripped: sharing apps frequently
      // append a trailing newline.
      expect(received, [const IncomingShare('A note')]);
    });
  });

  group('IncomingShareController', () {
    test('the mailbox is single-use', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(incomingShareProvider.notifier);

      expect(controller.consume(), isNull);

      controller.receive(const IncomingShare('shared text'));
      expect(container.read(incomingShareProvider),
          const IncomingShare('shared text'));

      expect(controller.consume(), const IncomingShare('shared text'));
      // The second read is empty: otherwise the same share would be pasted
      // again every time the panel was rebuilt.
      expect(controller.consume(), isNull);
      expect(container.read(incomingShareProvider), isNull);
    });
  });
}
