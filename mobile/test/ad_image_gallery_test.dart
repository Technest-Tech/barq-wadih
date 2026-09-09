import 'dart:io';
import 'dart:ui' as ui;

import 'package:barq_wadih/features/ads/domain/ad_model.dart';
import 'package:barq_wadih/features/ads/presentation/widgets/ad_image_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> photoBytes(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFFB8DCEB),
  );
  // Contrasting edges make cropping obvious in previews.
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), 15),
    Paint()..color = Colors.red,
  );
  canvas.drawRect(
    Rect.fromLTWH(0, height - 15.0, width.toDouble(), 15),
    Paint()..color = Colors.blue,
  );
  canvas.drawRect(
    Rect.fromLTWH(0, 15, 15, height - 30.0),
    Paint()..color = Colors.green,
  );
  canvas.drawRect(
    Rect.fromLTWH(width - 15.0, 15, 15, height - 30.0),
    Paint()..color = Colors.orange,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryImage portrait;
  late MemoryImage landscape;
  const first = AdImageModel(
    id: 1,
    imageUrl: 'https://example.com/portrait',
    thumbnailUrl: '',
    sortOrder: 0,
  );
  const second = AdImageModel(
    id: 2,
    imageUrl: 'https://example.com/landscape',
    thumbnailUrl: '',
    sortOrder: 1,
    width: 400,
    height: 200,
  );

  setUpAll(() async {
    const previewFont = String.fromEnvironment('IMAGE_PREVIEW_FONT');
    if (previewFont.isNotEmpty) {
      await (FontLoader('Preview')..addFont(
            File(
              previewFont,
            ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
    portrait = MemoryImage(await photoBytes(200, 400));
    landscape = MemoryImage(await photoBytes(400, 200));
  });

  Widget app(Widget child, {String language = 'en', double textScale = 1}) =>
      MaterialApp(
        theme: ThemeData(
          fontFamily: const String.fromEnvironment('IMAGE_PREVIEW_FONT').isEmpty
              ? null
              : 'Preview',
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        locale: Locale(language),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: child,
      );

  Future<void> settleImages(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'portrait and landscape keep decoded proportions without metadata',
    (tester) async {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 300,
                child: Column(
                  children: [
                    AdPhoto(image: first, provider: portrait),
                    AdPhoto(image: second, provider: landscape),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await settleImages(tester);
      expect(tester.getSize(find.byType(Image).at(0)), const Size(300, 600));
      expect(tester.getSize(find.byType(Image).at(1)), const Size(300, 150));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('gallery stacks photos and opens the selected photo fullscreen', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 200,
              child: AdImageGallery(
                adId: 9,
                images: const [first, second],
                imageProviderBuilder: (image) =>
                    image.id == 1 ? portrait : landscape,
              ),
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);
    expect(find.byType(PageView), findsNothing);
    expect(
      tester.getTopLeft(find.byType(AdPhoto).at(1)).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AdPhoto).first).dy),
    );
    await tester.ensureVisible(find.byTooltip('View fullscreen').last);
    await tester.tap(find.byTooltip('View fullscreen').last);
    await settleImages(tester);
    expect(
      tester.widget<AdImageFullscreen>(find.byType(AdImageFullscreen)).image.id,
      2,
    );
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AdImageFullscreen), findsNothing);
    expect(find.byType(AdImageGallery), findsOneWidget);
  });

  testWidgets(
    'fullscreen supports zoom buttons, limits, reset and double tap',
    (tester) async {
      await tester.pumpWidget(
        app(AdImageFullscreen(image: first, provider: portrait)),
      );
      await settleImages(tester);
      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      expect(controller.value.getMaxScaleOnAxis(), 1);
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pump();
      expect(controller.value.getMaxScaleOnAxis(), 1.5);
      await tester.tap(find.byTooltip('Zoom out'));
      await tester.pump();
      expect(controller.value.getMaxScaleOnAxis(), 1);
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byTooltip('Zoom in'));
        await tester.pump();
      }
      expect(controller.value.getMaxScaleOnAxis(), 5);
      expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.zoom_in))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Reset'));
      await tester.pump();
      final center = tester.getCenter(find.byType(InteractiveViewer));
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(center);
      await tester.pumpAndSettle();
      expect(controller.value.getMaxScaleOnAxis(), 2.5);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(center);
      await tester.pumpAndSettle();
      expect(controller.value.getMaxScaleOnAxis(), 1);
    },
  );

  testWidgets('pinch zoom and pan work with touch gestures', (tester) async {
    await tester.pumpWidget(
      app(AdImageFullscreen(image: second, provider: landscape)),
    );
    await settleImages(tester);
    final viewer = find.byType(InteractiveViewer);
    final controller = tester
        .widget<InteractiveViewer>(viewer)
        .transformationController!;
    final center = tester.getCenter(viewer);
    final left = await tester.startGesture(
      center - const Offset(40, 0),
      pointer: 1,
    );
    final right = await tester.startGesture(
      center + const Offset(40, 0),
      pointer: 2,
    );
    await tester.pump();
    await left.moveTo(center - const Offset(100, 0));
    await right.moveTo(center + const Offset(100, 0));
    await tester.pump();
    await left.up();
    await right.up();
    await tester.pumpAndSettle();
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1));
    final before = controller.value.clone();
    await tester.drag(viewer, const Offset(30, 20));
    await tester.pumpAndSettle();
    expect(controller.value, isNot(before));
  });

  testWidgets('empty gallery is usable', (tester) async {
    await tester.pumpWidget(
      app(const Scaffold(body: AdImageGallery(adId: 9, images: []))),
    );
    expect(find.byType(PageView), findsNothing);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic narrow-screen gallery and fullscreen fit enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            child: AdImageGallery(
              adId: 9,
              images: const [second, first],
              imageProviderBuilder: (image) =>
                  image.id == 1 ? portrait : landscape,
            ),
          ),
        ),
        language: 'ar',
        textScale: 2,
      ),
    );
    await settleImages(tester);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('IMAGE_PREVIEWS')) {
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('/tmp/barq-gallery-ar.png'),
      );
    }
    await tester.tap(find.byTooltip('عرض بملء الشاشة').first);
    await settleImages(tester);
    if (const bool.fromEnvironment('IMAGE_PREVIEWS')) {
      await expectLater(
        find.byType(Scaffold).last,
        matchesGoldenFile('/tmp/barq-fullscreen-ar.png'),
      );
    }
    expect(tester.takeException(), isNull);
  });
}
