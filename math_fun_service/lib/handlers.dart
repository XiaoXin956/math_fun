import 'package:mysql2/mysql2.dart';

import 'auth.dart';
import 'db.dart';
import 'http_router.dart';
import 'question_generator.dart';

/// 全部 REST 接口处理器。所有返回值均为可直接 jsonEncode 的 Map/List。

// ---------- 校验工具 ----------

int _int(dynamic v) => (v is num ? v.toInt() : int.tryParse('$v') ?? -1);

void _checkUsername(String username) {
  if (!RegExp(r'^[A-Za-z0-9_]{3,20}$').hasMatch(username)) {
    throw const ApiError(400, '用户名需为 3-20 位字母、数字或下划线');
  }
}

void _checkPassword(String password) {
  if (password.length < 6 || password.length > 64) {
    throw const ApiError(400, '密码长度需为 6-64 位');
  }
}

void _checkGrade(int grade) {
  if (grade < 1 || grade > 6) {
    throw const ApiError(400, '年级需为 1-6（小学一至六年级）');
  }
}

String _str(Map<String, dynamic> body, String key) {
  final v = body[key];
  return v is String ? v.trim() : '';
}

// ---------- 认证 ----------

Future<Map<String, dynamic>> register(RouteContext ctx) async {
  final username = _str(ctx.body, 'username');
  final password = _str(ctx.body, 'password');
  final nickname = _str(ctx.body, 'nickname');
  final role = _str(ctx.body, 'role');
  final grade = _int(ctx.body['grade']);

  _checkUsername(username);
  _checkPassword(password);
  if (nickname.isEmpty || nickname.length > 32) {
    throw const ApiError(400, '昵称不能为空且不超过 32 字');
  }
  if (role != 'parent' && role != 'child') {
    throw const ApiError(400, '角色需为 parent 或 child');
  }
  if (role == 'child') {
    _checkGrade(grade);
  }

  final salt = newSalt();
  final hash = hashPassword(salt, password);

  final result = await Db.withConn((conn) async {
    final res = await conn.query(
        'INSERT INTO users (username, password_hash, salt, nickname, role, grade) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [username, hash, salt, nickname, role, role == 'child' ? grade : null]);
    return res.insertId;
  });

  final token = await createSession(result);
  final user = await _loadUser(result);
  return {'token': token, 'user': user};
}

Future<Map<String, dynamic>> login(RouteContext ctx) async {
  final username = _str(ctx.body, 'username');
  final password = _str(ctx.body, 'password');
  if (username.isEmpty || password.isEmpty) {
    throw const ApiError(400, '请输入用户名和密码');
  }

  final rows = await Db.withConn((conn) async {
    final res = await conn.query(
        'SELECT id, username, nickname, role, grade, parent_id, points, salt, password_hash '
        'FROM users WHERE username = ?',
        [username]);
    return res.rows;
  });
  if (rows.isEmpty) {
    throw const ApiError(401, '用户名或密码错误');
  }
  final row = rows.first;
  final hash = hashPassword(row[7] as String, password);
  if (hash != row[8]) {
    throw const ApiError(401, '用户名或密码错误');
  }

  final token = await createSession(row[0] as int);
  return {'token': token, 'user': userMap(row)};
}

Future<Map<String, dynamic>> logout(RouteContext ctx) async {
  final auth = ctx.header('authorization');
  final token = auth.startsWith('Bearer ') ? auth.substring(7).trim() : '';
  if (token.isNotEmpty) {
    await Db.withConn((conn) async {
      await conn.query('DELETE FROM sessions WHERE token = ?', [token]);
    });
  }
  return {'ok': true};
}

Future<Map<String, dynamic>> me(RouteContext ctx) async {
  final user = await requireUser(ctx.request.headers);
  final children = await _childrenOf(user['id'] as int);
  return {'user': user, 'children': children};
}

Future<Map<String, dynamic>> _loadUser(int id) async {
  final rows = await Db.withConn((conn) async {
    final res = await conn.query(
        'SELECT id, username, nickname, role, grade, parent_id, points '
        'FROM users WHERE id = ?',
        [id]);
    return res.rows;
  });
  return userMap(rows.first);
}

Future<List<Map<String, dynamic>>> _childrenOf(int parentId) async {
  final rows = await Db.withConn((conn) async {
    final res = await conn.query(
        'SELECT id, username, nickname, role, grade, parent_id, points FROM users '
        "WHERE parent_id = ? AND role = 'child' ORDER BY id",
        [parentId]);
    return res.rows;
  });
  return rows.map(userMap).toList();
}

// ---------- 年级配置 ----------

Map<String, dynamic> grades() {
  return {
    'grades': gradeConfigs.map((c) {
      return {
        'grade': c.grade,
        'name': c.name,
        'ops': c.ops.map((o) => opSymbol(o)).toList(),
      };
    }).toList(),
  };
}

// ---------- 题目生成 ----------

Future<Map<String, dynamic>> generateQuestions(RouteContext ctx) async {
  await requireUser(ctx.request.headers);

  final grade = _int(ctx.body['grade']);
  _checkGrade(grade);
  final operation = _str(ctx.body, 'operation');
  final type = _str(ctx.body, 'type');
  if (type != 'math' && type != 'handwriting') {
    throw const ApiError(400, 'type 需为 math 或 handwriting');
  }
  final count = _int(ctx.body['count']).clamp(1, 10);

  final questions = generateBatch(grade: grade, operation: operation, count: count);

  final list = <Map<String, dynamic>>[];
  await Db.withConn((conn) async {
    for (final (expression, answer) in questions) {
      final id = newQuestionId();
      await conn.query(
          'INSERT INTO questions (id, expression, answer, grade, type) '
          'VALUES (?, ?, ?, ?, ?)',
          [id, expression, answer, grade, type]);
      // 注意：不向客户端返回答案，答案只在服务端保存，判分在提交时进行
      list.add({
        'id': id,
        'expression': expression,
        'grade': grade,
        'type': type,
      });
    }
  });
  return {'questions': list};
}

// ---------- 提交答案判分 ----------

Future<Map<String, dynamic>> submitResult(RouteContext ctx) async {
  final user = await requireUser(ctx.request.headers);

  final questionId = _str(ctx.body, 'question_id');
  final userId = user['id'] as int;
  final mode = _str(ctx.body, 'mode');
  final grade = _int(ctx.body['grade']);
  final userAnswer = _int(ctx.body['user_answer']);
  final durationMs = _int(ctx.body['duration_ms']).clamp(0, 600000);

  if (questionId.isEmpty) throw const ApiError(400, '缺少题目 ID');
  if (!['practice', 'challenge', 'timed'].contains(mode)) {
    throw const ApiError(400, 'mode 需为 practice/challenge/timed');
  }

  final row = await Db.withConn((conn) async {
    final res = await conn.query(
        'SELECT answer, expression, grade FROM questions WHERE id = ?',
        [questionId]);
    return res.rows.isEmpty ? null : res.rows.first;
  });
  if (row == null) {
    throw const ApiError(404, '题目不存在或已过期，请重新出题');
  }

  final answer = row[0] as int;
  final expression = row[1] as String;
  final correct = userAnswer == answer;

  await Db.withConn((conn) async {
    await conn.query(
        'INSERT INTO records '
        '(user_id, question_id, expression, answer, user_answer, correct, mode, grade, duration_ms) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          userId,
          questionId,
          expression,
          answer,
          userAnswer,
          correct ? 1 : 0,
          mode,
          _int(row[2]),
          durationMs,
        ]);
  });

  return {
    'correct': correct,
    'answer': answer,
    'message': correct ? _praise() : '没关系，正确答案是 $answer，再试一次！',
  };
}

String _praise() {
  final list = const [
    '太棒了，答对了！🎉',
    '你真聪明！⭐',
    '完全正确，继续加油！🎊',
    '哇，好厉害！🏆',
  ];
  final i = DateTime.now().millisecond;
  return list[i % list.length];
}

// ---------- 历史成绩 ----------

Future<Map<String, dynamic>> history(RouteContext ctx) async {
  final user = await requireUser(ctx.request.headers);
  final limit = int.tryParse(ctx.query['limit'] ?? '50')?.clamp(1, 200) ?? 50;

  final rows = await Db.withConn((conn) async {
    final res = await conn.query(
        'SELECT expression, answer, user_answer, correct, mode, grade, created_at '
        'FROM records WHERE user_id = ? ORDER BY created_at DESC LIMIT ?',
        [user['id'], limit]);
    return res.rows;
  });
  return {'records': rows.map(_recordMap).toList()};
}

Map<String, dynamic> _recordMap(MySqlRow row) {
  final created = row[6] as DateTime?;
  return {
    'expression': row[0],
    'answer': row[1],
    'userAnswer': row[2],
    'correct': row[3] == 1,
    'mode': row[4],
    'grade': row[5],
    'createdAt': created?.toIso8601String() ?? '',
  };
}

// ---------- 统计 ----------

Future<Map<String, dynamic>> stats(RouteContext ctx) async {
  final user = await requireUser(ctx.request.headers);
  final role = user['role'] as String;
  final userId = user['id'] as int;

  final userIds = <int>[userId];
  if (role == 'parent') {
    final children = await _childrenOf(userId);
    userIds.addAll(children.map((c) => c['id'] as int));
  }

  final rows = await Db.withConn((conn) async {
    final placeholders = userIds.map((_) => '?').join(',');
    final res = await conn.query(
        'SELECT COUNT(*) AS total, '
        'SUM(correct = 1) AS correct, '
        'COUNT(DISTINCT user_id) AS players, '
        'SUM(mode = "timed" AND correct = 1) AS timed_correct '
        'FROM records WHERE user_id IN ($placeholders)',
        userIds);
    return res.rows;
  });
  final row = rows.first;
  final total = (row[0] as num).toInt();
  final correct = (row[1] as num).toInt();

  return {
    'totalAnswered': total,
    'totalCorrect': correct,
    'accuracy': total == 0 ? 0.0 : correct / total,
    'players': (row[2] as num).toInt(),
  };
}

// ---------- 闯关进度 ----------

const int _challengeLevelsPerGrade = 5;
const double _passRatio = 0.7;
const double _threeStarRatio = 0.9;

Future<Map<String, dynamic>> challengeProgress(RouteContext ctx) async {
  final user = await requireUser(ctx.request.headers);
  final grade = int.tryParse(ctx.query['grade'] ?? '') ?? 1;
  _checkGrade(grade);

  final rows = await Db.withConn((conn) async {
    final res = await conn.query(
        'SELECT level, best_correct, best_total, best_stars FROM challenge_progress '
        'WHERE user_id = ? AND grade = ?',
        [user['id'], grade]);
    return res.rows;
  });

  final best = {
    for (final row in rows) (row[0] as int): {'correct': row[1], 'total': row[2], 'stars': row[3]}
  };

  final levels = <Map<String, dynamic>>[];
  for (var level = 1; level <= _challengeLevelsPerGrade; level++) {
    final data = best[level];
    final passed = data != null &&
        (data['correct'] as int) >= _passRatio * (data['total'] as int);
    final unlocked = level == 1 || (best[level - 1]?.containsKey('correct') ?? false) &&
        (best[level - 1]!['correct'] as int) >=
            _passRatio * (best[level - 1]!['total'] as int);
    levels.add({
      'level': level,
      'questions': 4 + level,
      'bestCorrect': data?['correct'] ?? 0,
      'bestTotal': data?['total'] ?? 0,
      'stars': data?['stars'] ?? 0,
      'passed': passed,
      'unlocked': unlocked,
    });
  }
  return {'grade': grade, 'levels': levels};
}

Future<Map<String, dynamic>> completeChallenge(RouteContext ctx) async {
  final user = await requireUser(ctx.request.headers);
  final grade = _int(ctx.body['grade']);
  final level = _int(ctx.body['level']);
  final correct = _int(ctx.body['correct']);
  final total = _int(ctx.body['total']);

  _checkGrade(grade);
  if (level < 1 || level > _challengeLevelsPerGrade) {
    throw const ApiError(400, '关卡需为 1-5');
  }
  if (total < 1 || correct < 0 || correct > total) {
    throw const ApiError(400, '提交的答题数据不合法');
  }

  final accuracy = correct / total;
  final passed = accuracy >= _passRatio;
  final stars = (accuracy >= _threeStarRatio ? 3 : (passed ? 2 : 0)) as int;

  await Db.withConn((conn) async {
    await conn.query(
        'INSERT INTO challenge_progress (user_id, grade, level, best_correct, best_total, best_stars) '
        'VALUES (?, ?, ?, ?, ?, ?) '
        'ON DUPLICATE KEY UPDATE '
        'best_correct = GREATEST(best_correct, VALUES(best_correct)), '
        'best_total = GREATEST(best_total, VALUES(best_total)), '
        'best_stars = GREATEST(best_stars, VALUES(best_stars))',
        [user['id'], grade, level, correct, total, stars]);
  });

  // 积分规则：成功率 >= 95% 加 3 分；80%~95% 不加不减；不足 80%（含 60%）扣 3 分
  // 同一关卡 7 天内重复挑战不再加分
  final userId = user['id'] as int;
  final since = DateTime.now().subtract(const Duration(days: 7));
  final recentAward = await Db.withConn((conn) async {
    final res = await conn.query(
        'SELECT id FROM points_records '
        'WHERE user_id = ? AND grade = ? AND level = ? AND change > 0 AND created_at >= ? '
        'LIMIT 1',
        [userId, grade, level, since]);
    return res.rows.isNotEmpty;
  });

  Map<String, dynamic> points;
  if (recentAward) {
    points = {
      'changed': 0,
      'reason': '7天内本关已获得过积分，本次不再加分',
    };
  } else if (accuracy >= 0.95) {
    points = await _awardPoints(
        userId, 3, '闯关成功率≥95%，奖励+3分', grade, level);
  } else if (accuracy >= 0.80) {
    points = {'changed': 0, 'reason': '闯关成功率在80%~95%之间，不加分也不扣分'};
  } else {
    points = await _awardPoints(
        userId, -3, '闯关成功率不足80%，扣3分', grade, level);
  }

  return {
    'passed': passed,
    'stars': stars,
    'accuracy': accuracy,
    'nextUnlocked': passed && level < _challengeLevelsPerGrade,
    'points': points,
  };
}

/// 中途退出闯关：扣 5 分
Future<Map<String, dynamic>> quitChallenge(RouteContext ctx) async {
  final user = await requireUser(ctx.request.headers);
  final grade = _int(ctx.body['grade']);
  final level = _int(ctx.body['level']);
  _checkGrade(grade);
  if (level < 1 || level > _challengeLevelsPerGrade) {
    throw const ApiError(400, '关卡需为 1-5');
  }
  final points = await _awardPoints(
      user['id'] as int, -5, '闯关中途退出，扣5分', grade, level);
  return {'ok': true, 'points': points};
}

/// 积分变动：更新用户总分并写入积分记录。
Future<Map<String, dynamic>> _awardPoints(
    int userId, int change, String reason, int grade, int level) async {
  await Db.withConn((conn) async {
    await conn.query('UPDATE users SET points = points + ? WHERE id = ?',
        [change, userId]);
    await conn.query(
        'INSERT INTO points_records (user_id, grade, level, change, reason) '
        'VALUES (?, ?, ?, ?, ?)',
        [userId, grade, level, change, reason]);
  });
  return {'changed': change, 'reason': reason};
}

/// 积分记录与总分
Future<Map<String, dynamic>> pointsHistory(RouteContext ctx) async {
  final user = await requireUser(ctx.request.headers);
  final limit = int.tryParse(ctx.query['limit'] ?? '50')?.clamp(1, 200) ?? 50;

  final total = await Db.withConn((conn) async {
    final res = await conn.query('SELECT points FROM users WHERE id = ?',
        [user['id']]);
    return res.rows.isEmpty ? 0 : (res.rows.first[0] as num).toInt();
  });

  final rows = await Db.withConn((conn) async {
    final res = await conn.query(
        'SELECT change, reason, grade, level, created_at FROM points_records '
        'WHERE user_id = ? ORDER BY created_at DESC LIMIT ?',
        [user['id'], limit]);
    return res.rows;
  });

  return {
    'total': total,
    'records': rows.map((row) {
      final created = row[4] as DateTime?;
      return {
        'change': row[0],
        'reason': row[1],
        'grade': row[2],
        'level': row[3],
        'createdAt': created?.toIso8601String() ?? '',
      };
    }).toList(),
  };
}

// ---------- 限时挑战最佳成绩 ----------

Future<Map<String, dynamic>> submitTimed(RouteContext ctx) async {
  final user = await requireUser(ctx.request.headers);
  final grade = _int(ctx.body['grade']);
  final score = _int(ctx.body['score']);
  final correct = _int(ctx.body['correct']);
  _checkGrade(grade);

  await Db.withConn((conn) async {
    await conn.query(
        'INSERT INTO timed_best (user_id, grade, best_score, best_correct) '
        'VALUES (?, ?, ?, ?) '
        'ON DUPLICATE KEY UPDATE '
        'best_score = GREATEST(best_score, VALUES(best_score)), '
        'best_correct = GREATEST(best_correct, VALUES(best_correct))',
        [user['id'], grade, score, correct]);
  });

  return {'ok': true, 'score': score};
}

Future<Map<String, dynamic>> timedBest(RouteContext ctx) async {
  final user = await requireUser(ctx.request.headers);
  final grade = int.tryParse(ctx.query['grade'] ?? '') ?? 0;

  final rows = await Db.withConn((conn) async {
    final res = await conn.query(
        'SELECT grade, best_score, best_correct FROM timed_best WHERE user_id = ?',
        [user['id']]);
    return res.rows;
  });
  return {
    'best': rows
        .where((r) => grade == 0 || r[0] == grade)
        .map((r) => {'grade': r[0], 'score': r[1], 'correct': r[2]})
        .toList(),
  };
}

// ---------- 手写答案：孩子提交，家长批改 ----------

/// 孩子提交手写答案（base64 PNG 图片）
Future<Map<String, dynamic>> submitHandwriting(RouteContext ctx) async {
  final user = await requireUser(ctx.request.headers);
  final questionId = _str(ctx.body, 'question_id');
  final image = _str(ctx.body, 'image');

  if (questionId.isEmpty) throw const ApiError(400, '缺少题目 ID');
  if (image.length < 100) {
    throw const ApiError(400, '手写答案图片无效');
  }
  if (image.length > 2000000) {
    throw const ApiError(400, '手写答案图片过大，请重绘后提交');
  }

  final row = await Db.withConn((conn) async {
    final res = await conn.query(
        'SELECT expression, answer, type FROM questions WHERE id = ?',
        [questionId]);
    return res.rows.isEmpty ? null : res.rows.first;
  });
  if (row == null) {
    throw const ApiError(404, '题目不存在或已过期，请重新出题');
  }
  if (row[2] != 'handwriting') {
    throw const ApiError(400, '该题目不是手写题');
  }

  await Db.withConn((conn) async {
    await conn.query(
        'INSERT INTO handwriting_submissions '
        '(user_id, question_id, expression, answer, image, status) '
        'VALUES (?, ?, ?, ?, ?, "pending")',
        [
          user['id'],
          questionId,
          row[0],
          row[1],
          image,
        ]);
  });

  return {'ok': true, 'message': '已提交，等待家长批改'};
}

/// 家长查看待批改列表
Future<Map<String, dynamic>> pendingHandwriting(RouteContext ctx) async {
  final parent = await requireUser(ctx.request.headers);
  if (parent['role'] != 'parent') {
    throw const ApiError(403, '只有家长账号可以批改手写答案');
  }
  final children = await _childrenOf(parent['id'] as int);
  final childIds = children.map((c) => c['id'] as int).toList();
  if (childIds.isEmpty) {
    return {'submissions': <Map<String, dynamic>>[], 'total': 0};
  }

  final placeholders = childIds.map((_) => '?').join(',');
  final rows = await Db.withConn((conn) async {
    final res = await conn.query(
        'SELECT s.id, s.user_id, s.expression, s.answer, s.image, s.created_at, u.nickname '
        'FROM handwriting_submissions s JOIN users u ON u.id = s.user_id '
        'WHERE s.user_id IN ($placeholders) AND s.status = "pending" '
        'ORDER BY s.created_at DESC LIMIT 50',
        childIds);
    return res.rows;
  });

  final list = rows.map((row) {
    final created = row[5] as DateTime?;
    return {
      'id': row[0],
      'childId': row[1],
      'childName': row[6],
      'expression': row[2],
      'answer': row[3],
      'image': row[4],
      'createdAt': created?.toIso8601String() ?? '',
    };
  }).toList();
  return {'submissions': list, 'total': list.length};
}

/// 家长批改：确认正确加分、否则扣分，分值由家长决定（0-10）
Future<Map<String, dynamic>> reviewHandwriting(RouteContext ctx) async {
  final parent = await requireUser(ctx.request.headers);
  if (parent['role'] != 'parent') {
    throw const ApiError(403, '只有家长账号可以批改手写答案');
  }
  final submissionId = _int(ctx.body['submission_id']);
  final correct = ctx.body['correct'];
  final points = _int(ctx.body['points']);

  if (submissionId < 1) throw const ApiError(400, '缺少提交记录 ID');
  if (correct is not bool) {
    throw const ApiError(400, '请选择判断结果（正确/错误）');
  }
  if (points < 0 || points > 10) {
    throw const ApiError(400, '积分绝对值不能超过 10');
  }

  final rows = await Db.withConn((conn) async {
    final res = await conn.query(
        'SELECT s.id, s.user_id, s.status FROM handwriting_submissions s '
        'JOIN users u ON u.id = s.user_id '
        'WHERE s.id = ? AND u.parent_id = ?',
        [submissionId, parent['id']]);
    return res.rows;
  });
  if (rows.isEmpty) {
    throw const ApiError(404, '提交记录不存在');
  }
  final row = rows.first;
  if (row[2] != 'pending') {
    throw const ApiError(400, '该提交已批改过，不能重复批改');
  }
  final childId = row[1] as int;

  final change = correct ? points : -points;
  final reason = correct
      ? '手写答案批改为正确，+$points 分'
      : '手写答案批改为错误，-$points 分';

  await Db.withConn((conn) async {
    await conn.query('UPDATE users SET points = points + ? WHERE id = ?',
        [change, childId]);
    await conn.query(
        'INSERT INTO points_records (user_id, grade, level, change, reason) '
        'VALUES (?, 0, 0, ?, ?)',
        [childId, change, reason]);
    await conn.query(
        'UPDATE handwriting_submissions '
        'SET status = "reviewed", reviewed_by = ?, review_change = ?, reviewed_at = NOW() '
        'WHERE id = ?',
        [parent['id'], change, submissionId]);
  });

  return {'ok': true, 'changed': change, 'reason': reason};
}

// ---------- 家长端：孩子管理 ----------

Future<Map<String, dynamic>> addChild(RouteContext ctx) async {
  final parent = await requireUser(ctx.request.headers);
  if (parent['role'] != 'parent') {
    throw const ApiError(403, '只有家长账号可以添加孩子');
  }

  final username = _str(ctx.body, 'username');
  final password = _str(ctx.body, 'password');
  final nickname = _str(ctx.body, 'nickname');
  final grade = _int(ctx.body['grade']);

  _checkUsername(username);
  _checkPassword(password);
  if (nickname.isEmpty || nickname.length > 32) {
    throw const ApiError(400, '昵称不能为空且不超过 32 字');
  }
  _checkGrade(grade);

  final exists = await Db.withConn((conn) async {
    final res = await conn.query('SELECT id FROM users WHERE username = ?', [username]);
    return res.rows.isNotEmpty;
  });
  if (exists) {
    throw const ApiError(409, '用户名已存在');
  }

  final salt = newSalt();
  final hash = hashPassword(salt, password);
  final id = await Db.withConn((conn) async {
    final res = await conn.query(
        'INSERT INTO users (username, password_hash, salt, nickname, role, grade, parent_id) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [username, hash, salt, nickname, 'child', grade, parent['id']]);
    return res.insertId;
  });

  return {'ok': true, 'child': await _loadUser(id)};
}

Future<Map<String, dynamic>> listChildren(RouteContext ctx) async {
  final parent = await requireUser(ctx.request.headers);
  if (parent['role'] != 'parent') {
    throw const ApiError(403, '只有家长账号可以查看孩子');
  }
  final children = await _childrenOf(parent['id'] as int);

  // 附带每个孩子的统计信息
  final result = <Map<String, dynamic>>[];
  for (final child in children) {
    final cid = child['id'] as int;
    final rows = await Db.withConn((conn) async {
      final res = await conn.query(
          'SELECT COUNT(*) AS total, SUM(correct = 1) AS correct, '
          'SUM(mode = "timed" AND correct = 1) AS timed_correct, '
          'COUNT(DISTINCT mode) AS modes '
          'FROM records WHERE user_id = ?',
          [cid]);
      return res.rows;
    });
    final row = rows.first;
    final total = (row[0] as num).toInt();
    final correct = (row[1] as num).toInt();
    result.add({
      ...child,
      'totalAnswered': total,
      'accuracy': total == 0 ? 0.0 : correct / total,
    });
  }
  return {'children': result};
}

Future<Map<String, dynamic>> childHistory(RouteContext ctx) async {
  final parent = await requireUser(ctx.request.headers);
  if (parent['role'] != 'parent') {
    throw const ApiError(403, '只有家长账号可以查看孩子成绩');
  }
  final childId = int.tryParse(ctx.params['id'] ?? '') ?? -1;

  final rows = await Db.withConn((conn) async {
    final res = await conn.query(
        'SELECT id, username, nickname, grade FROM users '
        "WHERE id = ? AND parent_id = ? AND role = 'child'",
        [childId, parent['id']]);
    return res.rows;
  });
  if (rows.isEmpty) {
    throw const ApiError(404, '孩子不存在');
  }

  final limit = int.tryParse(ctx.query['limit'] ?? '50')?.clamp(1, 200) ?? 50;
  final records = await Db.withConn((conn) async {
    final res = await conn.query(
        'SELECT expression, answer, user_answer, correct, mode, grade, created_at '
        'FROM records WHERE user_id = ? ORDER BY created_at DESC LIMIT ?',
        [childId, limit]);
    return res.rows;
  });

  return {
    'child': {
      'id': rows.first[0],
      'username': rows.first[1],
      'nickname': rows.first[2],
      'grade': rows.first[3],
    },
    'records': records.map(_recordMap).toList(),
  };
}
