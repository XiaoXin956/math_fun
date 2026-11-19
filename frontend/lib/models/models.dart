/// 前端数据模型。

class User {
  final int id;
  final String username;
  final String nickname;
  final String role; // parent / child
  final int? grade;
  final int? parentId;
  final int points;

  const User({
    required this.id,
    required this.username,
    required this.nickname,
    required this.role,
    required this.grade,
    required this.parentId,
    required this.points,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      nickname: json['nickname'] as String,
      role: json['role'] as String,
      grade: json['grade'] as int?,
      parentId: json['parentId'] as int?,
      points: json['points'] as int,
    );
  }

  bool get isParent => role == 'parent';
}

class Record {
  final String expression;
  final int answer;
  final int userAnswer;
  final bool correct;
  final String mode;
  final int grade;
  final String createdAt;

  const Record({
    required this.expression,
    required this.answer,
    required this.userAnswer,
    required this.correct,
    required this.mode,
    required this.grade,
    required this.createdAt,
  });

  factory Record.fromJson(Map<String, dynamic> json) {
    return Record(
      expression: json['expression'] as String,
      answer: json['answer'] as int,
      userAnswer: json['userAnswer'] as int,
      correct: json['correct'] as bool,
      mode: json['mode'] as String,
      grade: json['grade'] as int,
      createdAt: json['createdAt'] as String,
    );
  }

  String get modeLabel {
    switch (mode) {
      case 'practice':
        return '练习';
      case 'challenge':
        return '闯关';
      case 'timed':
        return '限时';
      default:
        return mode;
    }
  }

  String get timeLabel {
    if (createdAt.isEmpty) return '';
    try {
      final d = DateTime.parse(createdAt);
      return "${d.year}-${d.month.toString().padLeft(2, '0')}-"
          "${d.day.toString().padLeft(2, '0')} "
          "${d.hour.toString().padLeft(2, '0')}:"
          "${d.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return createdAt;
    }
  }
}

class Child extends User {
  int totalAnswered;
  double accuracy;

  Child(super.user, {required this.totalAnswered, required this.accuracy});

  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      User.fromJson(json),
      totalAnswered: json['totalAnswered'] as int,
      accuracy: (json['accuracy'] as num).toDouble(),
    );
  }
}

class LevelInfo {
  final int level;
  final int questions;
  final int bestCorrect;
  final int bestTotal;
  final int stars;
  final bool passed;
  final bool unlocked;

  const LevelInfo({
    required this.level,
    required this.questions,
    required this.bestCorrect,
    required this.bestTotal,
    required this.stars,
    required this.passed,
    required this.unlocked,
  });

  factory LevelInfo.fromJson(Map<String, dynamic> json) {
    return LevelInfo(
      level: json['level'] as int,
      questions: json['questions'] as int,
      bestCorrect: json['bestCorrect'] as int,
      bestTotal: json['bestTotal'] as int,
      stars: json['stars'] as int,
      passed: json['passed'] as bool,
      unlocked: json['unlocked'] as bool,
    );
  }
}

/// 积分记录
class PointsRecord {
  final int change;
  final String reason;
  final int grade;
  final int level;
  final String createdAt;

  const PointsRecord({
    required this.change,
    required this.reason,
    required this.grade,
    required this.level,
    required this.createdAt,
  });

  factory PointsRecord.fromJson(Map<String, dynamic> json) {
    return PointsRecord(
      change: json['change'] as int,
      reason: json['reason'] as String,
      grade: json['grade'] as int,
      level: json['level'] as int,
      createdAt: json['createdAt'] as String,
    );
  }

  String get timeLabel {
    if (createdAt.isEmpty) return '';
    try {
      final d = DateTime.parse(createdAt);
      return "${d.month.toString().padLeft(2, '0')}-"
          "${d.day.toString().padLeft(2, '0')} "
          "${d.hour.toString().padLeft(2, '0')}:"
          "${d.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return createdAt;
    }
  }
}

/// 手写答案提交（家长批改用）
class HandwritingSubmission {
  final int id;
  final int childId;
  final String childName;
  final String expression;
  final int answer;
  final String image; // base64 PNG
  final String createdAt;

  const HandwritingSubmission({
    required this.id,
    required this.childId,
    required this.childName,
    required this.expression,
    required this.answer,
    required this.image,
    required this.createdAt,
  });

  factory HandwritingSubmission.fromJson(Map<String, dynamic> json) {
    return HandwritingSubmission(
      id: json['id'] as int,
      childId: json['childId'] as int,
      childName: json['childName'] as String,
      expression: json['expression'] as String,
      answer: json['answer'] as int,
      image: json['image'] as String,
      createdAt: json['createdAt'] as String,
    );
  }
}
