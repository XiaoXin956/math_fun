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
    // 兼容 num/int/String 等数字类型，避免后端类型差异导致类型转换异常白屏
    int asInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    return Record(
      expression: (json['expression'] ?? '').toString(),
      answer: asInt(json['answer']),
      userAnswer: asInt(json['userAnswer']),
      correct: json['correct'] == true || json['correct'] == 1,
      mode: (json['mode'] ?? '').toString(),
      grade: asInt(json['grade']),
      createdAt: (json['createdAt'] ?? '').toString(),
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
          "${d.minute.toString().padLeft(2, '0')}:"
          "${d.second.toString().padLeft(2, '0')}";
    } catch (_) {
      return createdAt;
    }
  }

  /// 日期部分 yyyy-MM-dd，用于历史记录分组。
  String get dateLabel {
    if (createdAt.isEmpty) return '';
    try {
      final d = DateTime.parse(createdAt);
      return "${d.year}-${d.month.toString().padLeft(2, '0')}-"
          "${d.day.toString().padLeft(2, '0')}";
    } catch (_) {
      return createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;
    }
  }

  /// 分组标题用的完整玩法名。
  String get modeGroupLabel {
    switch (mode) {
      case 'practice':
        return '自由练习';
      case 'challenge':
        return '闯关挑战';
      case 'timed':
        return '限时挑战';
      default:
        return mode;
    }
  }

  /// 排序用的时间戳（毫秒），解析失败返回 0。
  int get createdMillis {
    try {
      return DateTime.parse(createdAt).millisecondsSinceEpoch;
    } catch (_) {
      return 0;
    }
  }
}

class Child extends User {
  int totalAnswered;
  double accuracy;

  Child(User user, {required this.totalAnswered, required this.accuracy})
      : super(
          id: user.id,
          username: user.username,
          nickname: user.nickname,
          role: user.role,
          grade: user.grade,
          parentId: user.parentId,
          points: user.points,
        );

  factory Child.fromJson(Map<String, dynamic> json) {
    final rawTotal = json['totalAnswered'];
    final rawAcc = json['accuracy'];
    return Child(
      User.fromJson(json),
      totalAnswered: rawTotal is int
          ? rawTotal
          : (rawTotal is num ? rawTotal.toInt() : int.tryParse('$rawTotal') ?? 0),
      accuracy: rawAcc is num
          ? rawAcc.toDouble()
          : double.tryParse('$rawAcc') ?? 0.0,
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

  /// 积分来源标签：闯关结算 / 中途退出 / 手写批改
  String get sourceLabel {
    if (reason.contains('手写')) return '手写批改';
    if (reason.contains('退出')) return '中途退出';
    if (reason.contains('闯关')) return '闯关结算';
    return '其他';
  }

  /// 关卡信息（闯关记录有年级与关卡号）
  String get levelLabel {
    if (level > 0 && grade > 0) return '${grade} 年级 第 $level 关';
    return '';
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

/// 一次手写练习（批次）= 一组，组内多道题，家长按组批改、整组一次给分。
class HandwritingBatch {
  final String batchId;
  final int childId;
  final String childName;
  final String createdAt;
  final List<HandwritingItem> items;

  const HandwritingBatch({
    required this.batchId,
    required this.childId,
    required this.childName,
    required this.createdAt,
    required this.items,
  });

  factory HandwritingBatch.fromJson(Map<String, dynamic> json) {
    return HandwritingBatch(
      batchId: json['batchId'] as String,
      childId: json['childId'] as int,
      childName: json['childName'] as String,
      createdAt: json['createdAt'] as String,
      items: (json['items'] as List)
          .map((e) => HandwritingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 批次内的一道手写题。
class HandwritingItem {
  final int id;
  final String expression;
  final int answer;
  final String image; // base64 PNG

  const HandwritingItem({
    required this.id,
    required this.expression,
    required this.answer,
    required this.image,
  });

  factory HandwritingItem.fromJson(Map<String, dynamic> json) {
    final rawAnswer = json['answer'];
    return HandwritingItem(
      id: json['id'] as int,
      expression: (json['expression'] ?? '').toString(),
      answer: rawAnswer is int
          ? rawAnswer
          : (rawAnswer is num ? rawAnswer.toInt() : int.tryParse('$rawAnswer') ?? 0),
      image: (json['image'] ?? '').toString(),
    );
  }
}
