// Ad comment models — a root question plus the replies posted under it.

class QuestionModel {
  final int id;
  final String body;
  final ({int id, String name, String? avatar}) user;
  final List<QuestionModel> replies;
  final DateTime createdAt;

  const QuestionModel({
    required this.id,
    required this.body,
    required this.user,
    this.replies = const [],
    required this.createdAt,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>? ?? const {};
    final repliesJson = json['replies'] as List<dynamic>? ?? const [];
    final name = (userJson['name'] as String?)?.trim() ?? '';

    return QuestionModel(
      id: json['id'] as int,
      body: json['body'] as String? ?? '',
      user: (
        id: userJson['id'] as int? ?? 0,
        name: name.isEmpty ? 'مستخدم' : name,
        avatar: userJson['avatar'] as String?,
      ),
      replies: repliesJson
          .map((e) => QuestionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  QuestionModel copyWith({List<QuestionModel>? replies}) => QuestionModel(
    id: id,
    body: body,
    user: user,
    replies: replies ?? this.replies,
    createdAt: createdAt,
  );
}
