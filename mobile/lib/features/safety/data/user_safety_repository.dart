import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class UserSafetyStatus {
  final bool isBlocked;
  final bool interactionBlocked;

  const UserSafetyStatus({
    required this.isBlocked,
    required this.interactionBlocked,
  });
}

class UserSafetyRepository {
  final Dio _dio;
  const UserSafetyRepository(this._dio);

  Future<UserSafetyStatus> status(int userId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/users/$userId/safety',
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return UserSafetyStatus(
        isBlocked: data['is_blocked'] == true,
        interactionBlocked: data['interaction_blocked'] == true,
      );
    } on DioException catch (e) {
      throw _error(e, 'تعذر التحقق من حالة المستخدم');
    }
  }

  Future<Set<String>> blockedUserIds() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/users/blocks');
      final data = response.data!['data'] as Map<String, dynamic>;
      return List<dynamic>.from(
        data['user_ids'] ?? const [],
      ).map((id) => id.toString()).toSet();
    } on DioException catch (e) {
      throw _error(e, 'تعذر تحميل قائمة الحظر');
    }
  }

  Future<void> block(int userId, {String? conversationId}) async {
    try {
      await _dio.post<void>(
        '/users/$userId/block',
        data: {if (conversationId != null) 'conversation_id': conversationId},
      );
    } on DioException catch (e) {
      throw _error(e, 'تعذر حظر المستخدم');
    }
  }

  Future<void> unblock(int userId) async {
    try {
      await _dio.delete<void>('/users/$userId/block');
    } on DioException catch (e) {
      throw _error(e, 'تعذر إلغاء الحظر');
    }
  }

  Future<void> report({
    required int userId,
    required String reason,
    String? description,
    String? conversationId,
  }) async {
    try {
      await _dio.post<void>(
        '/users/$userId/report',
        data: {
          'reason': reason,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          if (conversationId != null) 'conversation_id': conversationId,
        },
      );
    } on DioException catch (e) {
      throw _error(e, 'تعذر إرسال البلاغ');
    }
  }

  ApiException _error(DioException e, String fallback) {
    final data = e.response?.data;
    String? message;
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            message = value.first.toString();
            break;
          }
        }
      }
      message ??= data['message']?.toString();
    }
    return ApiException(
      message: message ?? fallback,
      statusCode: e.response?.statusCode,
    );
  }
}

final userSafetyRepositoryProvider = Provider<UserSafetyRepository>((ref) {
  return UserSafetyRepository(ref.watch(dioProvider));
});

final blockedUserIdsProvider = FutureProvider<Set<String>>((ref) {
  return ref.read(userSafetyRepositoryProvider).blockedUserIds();
});

final userSafetyStatusProvider = FutureProvider.family<UserSafetyStatus, int>((
  ref,
  userId,
) {
  return ref.read(userSafetyRepositoryProvider).status(userId);
});
