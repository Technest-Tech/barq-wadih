import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barq_wadih/features/ads/data/ad_api.dart';

/// PHP populates $_POST and $_FILES from a multipart body only on POST. A real
/// PATCH therefore reaches Laravel with nothing parsed: UpdateAdRequest's rules
/// are all `sometimes`, so the empty body validated fine and the API reported
/// success while writing nothing. The edit must go out as POST + `_method`.
void main() {
  late List<RequestOptions> sent;
  late AdRepository repo;

  setUp(() {
    sent = [];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sent.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': {
                    'id': 7,
                    'title': 'عنوان بعد التعديل',
                    'description': 'وصف جديد بعد التعديل',
                    'status': 'active',
                    'status_label': 'نشط',
                    'is_negotiable': false,
                    'is_free': false,
                    'is_boosted': false,
                    'images': <dynamic>[],
                    'created_at': '2026-09-01T10:00:00Z',
                  },
                },
              ),
            );
          },
        ),
      );
    repo = AdRepository(dio);
  });

  FormData editPayload() => FormData.fromMap({
    'title': 'عنوان بعد التعديل',
    'description': 'وصف جديد بعد التعديل',
    'price_hidden': '1',
    'remove_image_ids[]': ['3'],
  });

  test('editing an ad is sent as POST with a PATCH method override', () async {
    await repo.updateAd(7, editPayload());

    expect(sent, hasLength(1));
    final request = sent.single;
    expect(request.path, '/ads/7');
    expect(
      request.method,
      'POST',
      reason: 'a real PATCH loses the whole multipart body in PHP',
    );

    final fields = (request.data as FormData).fields;
    expect(
      fields.any((f) => f.key == '_method' && f.value == 'PATCH'),
      isTrue,
      reason: 'Laravel needs _method=PATCH to route the POST to ads.update',
    );
  });

  test('the edited fields still reach the request body', () async {
    await repo.updateAd(7, editPayload());

    final fields = (sent.single.data as FormData).fields;
    final byKey = {for (final f in fields) f.key: f.value};
    expect(byKey['title'], 'عنوان بعد التعديل');
    expect(byKey['description'], 'وصف جديد بعد التعديل');
    expect(byKey['price_hidden'], '1');
    expect(byKey['remove_image_ids[]'], '3');
  });
}
