import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barq_wadih/core/services/image_cache_manager.dart';
import 'package:barq_wadih/core/widgets/app_cached_image.dart';

class RealHttp extends HttpOverrides {}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory cacheDirectory;
  setUpAll(() {
    cacheDirectory = Directory.systemTemp.createTempSync(
      'feed-thumbnail-test-',
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => cacheDirectory.path,
    );
  });
  tearDownAll(() async {
    await AppImageCacheManager.instance.dispose();
    await cacheDirectory.delete(recursive: true);
  });
  testWidgets('thumbnail-only loading and original fallback', (tester) async {
    final previous = HttpOverrides.current;
    HttpOverrides.global = RealHttp();
    final requested = <String>[];
    final bytes = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(Colors.blue, BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(10, 10);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      return data!.buffer.asUint8List();
    });
    final server = await tester.runAsync(
      () => HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    addTearDown(() async {
      HttpOverrides.global = previous;
      await server!.close(force: true);
    });
    server!.listen((request) {
      requested.add('/${request.uri.pathSegments.last}');
      if (request.uri.pathSegments.first == 'fail' &&
          request.uri.pathSegments.last == 'thumb.png') {
        request.response.statusCode = 404;
      } else {
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.add(bytes!);
      }
      request.response.close();
    });
    for (final failThumbnail in [false, true]) {
      requested.clear();
      final base =
          'http://127.0.0.1:${server.port}/${failThumbnail ? 'fail' : 'ok'}';
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 110,
            height: 90,
            child: AppCachedImage(
              imageUrl: '$base/full.png',
              lowResolutionUrl: '$base/thumb.png',
              preferPreview: true,
            ),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      expect(
        requested,
        failThumbnail ? ['/thumb.png', '/full.png'] : ['/thumb.png'],
      );
      await tester.pumpWidget(const SizedBox());
    }
    await tester.pump(const Duration(seconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(seconds: 20));
  });
}
