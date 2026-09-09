import 'package:dio/dio.dart';

import '../domain/question_model.dart';

class QuestionRepository {
  final Dio _dio;
  QuestionRepository(this._dio);

  // ── Get the comments posted on an ad ──────────────────────────────────────

  Future<List<QuestionModel>> fetchAdQuestions(int adId, {int page = 1}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/ads/$adId/questions',
      queryParameters: {'page': page},
    );
    final data = (res.data?['data'] as List<dynamic>? ?? []);
    return data
        .map((e) => QuestionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Post a comment on an ad ───────────────────────────────────────────────

  Future<QuestionModel> postQuestion({
    required int adId,
    required String body,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/ads/$adId/questions',
      data: {'body': body},
    );
    return QuestionModel.fromJson(res.data?['data'] as Map<String, dynamic>);
  }

  // ── Reply to a comment (the seller answering a buyer) ─────────────────────

  Future<QuestionModel> postReply({
    required int questionId,
    required String body,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/questions/$questionId/reply',
      data: {'body': body},
    );
    return QuestionModel.fromJson(res.data?['data'] as Map<String, dynamic>);
  }
}
