import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barq_wadih/features/ads/data/ad_api.dart';
import 'package:barq_wadih/features/ads/domain/ad_model.dart';

typedef Feed = ({List<AdListModel> ads, bool hasMore, int total});
Feed feed(int id) => (
  ads: [
    AdListModel.fromJson({
      'id': id,
      'title': 'Ad $id',
      'created_at': '2026-09-01T10:00:00Z',
    }),
  ],
  hasMore: true,
  total: 100,
);

class PendingRepository extends AdRepository {
  PendingRepository() : super(Dio());
  final requests = <(AdsFilter, Completer<Feed>)>[];
  @override
  Future<Feed> getAds(AdsFilter filter) {
    final pending = Completer<Feed>();
    requests.add((filter, pending));
    return pending.future;
  }
}

void main() {
  late PendingRepository repo;
  late ProviderContainer container;
  setUp(() async {
    repo = PendingRepository();
    container = ProviderContainer(
      overrides: [adRepositoryProvider.overrideWithValue(repo)],
    );
    final initial = container.read(adsFeedProvider.future);
    repo.requests.last.$2.complete(feed(1));
    await initial;
  });
  tearDown(() => container.dispose());

  test(
    'refresh keeps old ads until replacement and blocks pagination',
    () async {
      final notifier = container.read(adsFeedProvider.notifier);
      final refresh = notifier.refresh();
      expect(container.read(adsFeedProvider).isLoading, false);
      expect(container.read(adsFeedProvider).value!.ads.single.id, 1);
      await notifier.loadMore();
      expect(repo.requests.length, 2);
      repo.requests.last.$2.complete(feed(2));
      await refresh;
      expect(container.read(adsFeedProvider).value!.ads.single.id, 2);
    },
  );

  test('failed refresh preserves ads and pagination cursor', () async {
    final notifier = container.read(adsFeedProvider.notifier);
    final more = notifier.loadMore();
    repo.requests.last.$2.complete(feed(2));
    await more;
    final refresh = notifier.refresh();
    final failure = expectLater(refresh, throwsStateError);
    repo.requests.last.$2.completeError(StateError('offline'));
    await failure;
    expect(container.read(adsFeedProvider).value!.ads.length, 2);
    final next = notifier.loadMore();
    expect(repo.requests.last.$1.page, 3);
    repo.requests.last.$2.complete(feed(3));
    await next;
  });

  test('late refresh cannot overwrite a newer filter', () async {
    final notifier = container.read(adsFeedProvider.notifier);
    final refresh = notifier.refresh();
    final oldRequest = repo.requests.last.$2;
    notifier.applyFilter(const AdsFilter(q: 'car'));
    repo.requests.last.$2.complete(feed(9));
    await container.read(adsFeedProvider.future);
    oldRequest.complete(feed(2));
    await refresh;
    expect(container.read(adsFeedProvider).value!.ads.single.id, 9);
  });
}
