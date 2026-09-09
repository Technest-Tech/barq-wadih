import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/question_model.dart';
import 'question_repository.dart';

// ── Repository provider ───────────────────────────────────────────────────────

final questionRepositoryProvider = Provider<QuestionRepository>((ref) {
  return QuestionRepository(ref.watch(dioProvider));
});

// ── Comments on an ad ─────────────────────────────────────────────────────────

final adQuestionsProvider = FutureProvider.family<List<QuestionModel>, int>((
  ref,
  adId,
) {
  return ref.watch(questionRepositoryProvider).fetchAdQuestions(adId);
});
