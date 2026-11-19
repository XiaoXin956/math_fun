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

/// mysql_client 的 typedAssoc() 可能把 DATETIME 映射为 DateTime，
/// 也可能保留字符串，统一处理成 ISO 字符串。
String _isoDateTime(dynamic v) {
  if (v is DateTime) return v.toIso8601String();
  final dt = DateTime.tryParse('$v');
  return dt == null ? '' : dt.toIso8601String();
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
    final res = await conn.execute(
        'INSERT INTO users (username, password_hash, salt, nickname, role, grade) '
        'VALUES (:username, :hash, :salt, :nickname, :role, :grade)',
        {
          'username': username,
          'hash': hash,
          'salt': salt,
          'nickname': nickname,
          'role': role,
          'grade': role == 'child' ? grade : null,
        });
    return res.lastInsertID.toInt();
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
    final res = await conn.execute(
        'SELECT id, username, nickname, role, grade, parent_id, points, salt, password_hash '
        'FROM users WHERE username = :username',
        {'username': username});
    return res.rows;
  });
  if (rows.isEmpty) {
    throw const ApiError(401, '用户名或密码错误');
  }
  final row = rows.first.typedAssoc();
  final hash = hashPassword(row['salt'] as String, password);
  if (hash != row['password_hash']) {
    throw const ApiError(401, '用户名或密码错误');
  }

  final token = await createSession(row['id'] as int);
  return {'token': token, 'user': userMap(row)};
}

Future<Map<String, dynamic>> logout(RouteContext ctx) async {
  final auth = ctx.header('authorization');
  final token = auth.startsWith('Bearer ') ? auth.substring(7).trim() : '';
  if (token.isNotEmpty) {
    await Db.withConn((conn) async {
      await conn.execute('DELETE FROM sessions WHERE token = :token', {'token': token});
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
    final res = await conn.execute(
        'SELECT id, username, nickname, role, grade, parent_id, points '
        'FROM users WHERE id = :id',
        {'id': id});
    return res.rows;
  });
  return userMap(rows.first.typedAssoc());
}

Future<List<Map<String, dynamic>>> _childrenOf(int parentId) async {
  final rows = await Db.withConn((conn) async {
    final res = await conn.execute(
        'SELECT id, username, nickname, role, grade, parent_id, points FROM users '
        "WHERE parent_id = :parentId AND role = 'child' ORDER BY id",
        {'parentId': parentId});
    return res.rows;
  });
  return rows.map((r) => userMap(r.typedAssoc())).toList();
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
      await conn.execute(
          'INSERT INTO questions (id, expression, answer, grade, type) '
          'VALUES (:id, :expression, :answer, :grade, :type)',
          {
            'id': id,
            'expression': expression,
            'answer': answer,
            'grade': grade,
            'type': type,
          });
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
  final userAnswer = _int(ctx.body['user_answer']);
  final durationMs = _int(ctx.body['duration_ms']).clamp(0, 600000);

  if (questionId.isEmpty) throw const ApiError(400, '缺少题目 ID');
  if (!['practice', 'challenge', 'timed'].contains(mode)) {
    throw const ApiError(400, 'mode 需为 practice/challenge/timed');
  }

  final row = await Db.withConn((conn) async {
    final res = await conn.execute(
        'SELECT answer, expression, grade FROM questions WHERE id = :qid',
        {'qid': questionId});
    return res.rows.isEmpty ? null : res.rows.first.typedAssoc();
  });
  if (row == null) {
    throw const ApiError(404, '题目不存在或已过期，请重新出题');
  }

  final answer = row['answer'] as int;
  final expression = row['expression'] as String;
  final correct = userAnswer == answer;

  await Db.withConn((conn) async {
    await conn.execute(
        'INSERT INTO records '
        '(user_id, question_id, expression, answer, user_answer, correct, mode, grade, duration_ms) '
        'VALUES (:userId, :qid, :expression, :answer, :userAnswer, :correct, :mode, :grade, :durationMs)',
        {
          'userId': userId,
          'qid': questionId,
          'expression': expression,
          'answer': answer,
          'userAnswer': userAnswer,
          'correct': correct ? 1 : 0,
          'mode': mode,
          'grade': _int(row['grade']),
          'durationMs': durationMs,
        });
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
    final res = await conn.execute(
        'SELECT expression, answer, user_answer, correct, mode, grade, created_at '
        'FROM records WHERE user_id = :userId ORDER BY created_at DESC LIMIT :limit',
        {'userId': user['id'], 'limit': limit});
    return res.rows;
  });
  return {'records': rows.map((r) => _recordMap(r.typedAssoc())).toList()};
}

Map<String, dynamic> _recordMap(Map<String, dynamic> row) {
  return {
    'expression': row['expression'],
    'answer': row['answer'],
    'userAnswer': row['user_answer'],
    'correct': row['correct'] == 1,
    'mode': row['mode'],
    'grade': row['grade'],
    'createdAt': _isoDateTime(row['created_at']),
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

  final row = await Db.withConn((conn) async {
    final params = <String, dynamic>{};
    final placeholders = List.generate(userIds.length, (i) {
      params['uid$i'] = userIds[i];
      return ':uid$i';
    }).join(',');
    final res = await conn.execute(
        'SELECT COUNT(*) AS total, '
        'SUM(correct = 1) AS correct, '
        'COUNT(DISTINCT user_id) AS players, '
        'SUM(mode = "timed" AND correct = 1) AS timed_correct '
        'FROM records WHERE user_id IN ($placeholders)',
        params);
    return res.rows.first.typedAssoc();
  });
  final total = (row['total'] as num).toInt();
  final correct = (row['correct'] as num).toInt();

  return {
    'totalAnswered': total,
    'totalCorrect': correct,
    'accuracy': total == 0 ? 0.0 : correct / total,
    'players': (row['players'] as num).toInt(),
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
    final res = await conn.execute(
        'SELECT level, best_correct, best_total, best_stars FROM challenge_progress '
        'WHERE user_id = :userId AND grade = :grade',
        {'userId': user['id'], 'grade': grade});
    return res.rows;
  });

  final best = {
    for (final row in rows)
      (row.typedColByName<int>('level')): {
        'correct': row.typedColByName<int>('best_correct'),
        'total': row.typedColByName<int>('best_total'),
        'stars': row.typedColByName<int>('best_stars'),
      }
  };

  final levels = <Map<String, dynamic>>[];
  for (var level = 1; level <= _challengeLevelsPerGrade; level++) {
    final data = best[level];
    final passed = data != null &&
        (data['correct'] as int) >= _passRatio * (data['total'] as int);
    final unlocked = level == 1 ||
        (best[level - 1]?.containsKey('correct') ?? false) &&
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
  final stars = accuracy >= _threeStarRatio ? 3 : (passed ? 2 : 0);

  await Db.withConn((conn) async {
    await conn.execute(
        'INSERT INTO challenge_progress (user_id, grade, level, best_correct, best_total, best_stars) '
        'VALUES (:userId, :grade, :level, :correct, :total, :stars) '
        'ON DUPLICATE KEY UPDATE '
        'best_correct = GREATEST(best_correct, :correct), '
        'best_total = GREATEST(best_total, :total), '
        'best_stars = GREATEST(best_stars, :stars)',
        {
          'userId': user['id'],
          'grade': grade,
          'level': level,
          'correct': correct,
          'total': total,
          'stars': stars,
        });
  });

  // 积分规则：成功率 >= 95% 加 3 分；80%~95% 不加不减；不足 80%（含 60%）扣 3 分
  // 同一关卡 7 天内重复挑战不再加分
  final userId = user['id'] as int;
  final recentAward = await Db.withConn((conn) async {
    final res = await conn.execute(
        'SELECT id FROM points_records '
        'WHERE user_id = :userId AND grade = :grade AND level = :level '
        'AND `change` > 0 AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) '
        'LIMIT 1',
        {'userId': userId, 'grade': grade, 'level': level});
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
    await conn.execute(
        'UPDATE users SET points = points + :change WHERE id = :userId',
        {'change': change, 'userId': userId});
    await conn.execute(
        'INSERT INTO points_records (user_id, grade, level, `change`, reason) '
        'VALUES (:userId, :grade, :level, :change, :reason)',
        {
          'userId': userId,
          'grade': grade,
          'level': level,
          'change': change,
          'reason': reason,
        });
  });
  return {'changed': change, 'reason': reason};
}

/// 积分记录与总分
Future<Map<String, dynamic>> pointsHistory(RouteContext ctx) async {
  final user = await requireUser(ctx.request.headers);
  final limit = int.tryParse(ctx.query['limit'] ?? '50')?.clamp(1, 200) ?? 50;

  final total = await Db.withConn((conn) async {
    final res = await conn.execute(
        'SELECT points FROM users WHERE id = :userId', {'userId': user['id']});
    return res.rows.isEmpty ? 0 : (res.rows.first.typedAssoc()['points'] as int);
  });

  final rows = await Db.withConn((conn) async {
    final res = await conn.execute(
        'SELECT `change`, reason, grade, level, created_at FROM points_records '
        'WHERE user_id = :userId ORDER BY created_at DESC LIMIT :limit',
        {'userId': user['id'], 'limit': limit});
    return res.rows;
  });

  return {
    'total': total,
    'records': rows.map((row) {
      final r = row.typedAssoc();
      return {
        'change': r['change'],
        'reason': r['reason'],
        'grade': r['grade'],
        'level': r['level'],
        'createdAt': _isoDateTime(r['created_at']),
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
    await conn.execute(
        'INSERT INTO timed_best (user_id, grade, best_score, best_correct) '
        'VALUES (:userId, :grade, :score, :correct) '
        'ON DUPLICATE KEY UPDATE '
        'best_score = GREATEST(best_score, :score), '
        'best_correct = GREATEST(best_correct, :correct)',
        {
          'userId': user['id'],
          'grade': grade,
          'score': score,
          'correct': correct,
        });
  });

  return {'ok': true, 'score': score};
}

Future<Map<String, dynamic>> timedBest(RouteContext ctx) async {
  final user = await requireUser(ctx.request.headers);
  final grade = int.tryParse(ctx.query['grade'] ?? '') ?? 0;

  final rows = await Db.withConn((conn) async {
    final res = await conn.execute(
        'SELECT grade, best_score, best_correct FROM timed_best WHERE user_id = :userId',
        {'userId': user['id']});
    return res.rows;
  });
  return {
    'best': rows
        .where((r) => grade == 0 || r.typedColByName<int>('grade') == grade)
        .map((r) => {
              'grade': r.typedColByName<int>('grade'),
              'score': r.typedColByName<int>('best_score'),
              'correct': r.typedColByName<int>('best_correct'),
            })
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
    final res = await conn.execute(
        'SELECT expression, answer, type FROM questions WHERE id = :qid',
        {'qid': questionId});
    return res.rows.isEmpty ? null : res.rows.first.typedAssoc();
  });
  if (row == null) {
    throw const ApiError(404, '题目不存在或已过期，请重新出题');
  }
  if (row['type'] != 'handwriting') {
    throw const ApiError(400, '该题目不是手写题');
  }

  await Db.withConn((conn) async {
    await conn.execute(
        'INSERT INTO handwriting_submissions '
        '(user_id, question_id, expression, answer, image, status) '
        'VALUES (:userId, :qid, :expression, :answer, :image, "pending")',
        {
          'userId': user['id'],
          'qid': questionId,
          'expression': row['expression'],
          'answer': row['answer'],
          'image': image,
        });
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

  final rows = await Db.withConn((conn) async {
    final params = <String, dynamic>{};
    final placeholders = List.generate(childIds.length, (i) {
      params['cid$i'] = childIds[i];
      return ':cid$i';
    }).join(',');
    final res = await conn.execute(
        'SELECT s.id, s.user_id, s.expression, s.answer, s.image, s.created_at, u.nickname '
        'FROM handwriting_submissions s JOIN users u ON u.id = s.user_id '
        'WHERE s.user_id IN ($placeholders) AND s.status = "pending" '
        'ORDER BY s.created_at DESC LIMIT 50',
        params);
    return res.rows;
  });

  final list = rows.map((row) {
    final r = row.typedAssoc();
    return {
      'id': r['id'],
      'childId': r['user_id'],
      'childName': r['nickname'],
      'expression': r['expression'],
      'answer': r['answer'],
      'image': r['image'],
      'createdAt': _isoDateTime(r['created_at']),
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
  if (correct is! bool) {
    throw const ApiError(400, '请选择判断结果（正确/错误）');
  }
  if (points < 0 || points > 10) {
    throw const ApiError(400, '积分绝对值不能超过 10');
  }

  final rows = await Db.withConn((conn) async {
    final res = await conn.execute(
        'SELECT s.id, s.user_id, s.status FROM handwriting_submissions s '
        'JOIN users u ON u.id = s.user_id '
        'WHERE s.id = :submissionId AND u.parent_id = :parentId',
        {'submissionId': submissionId, 'parentId': parent['id']});
    return res.rows;
  });
  if (rows.isEmpty) {
    throw const ApiError(404, '提交记录不存在');
  }
  final row = rows.first.typedAssoc();
  if (row['status'] != 'pending') {
    throw const ApiError(400, '该提交已批改过，不能重复批改');
  }
  final childId = row['user_id'] as int;

  final change = correct ? points : -points;
  final reason = correct
      ? '手写答案批改为正确，+$points 分'
      : '手写答案批改为错误，-$points 分';

  await Db.withConn((conn) async {
    await conn.execute(
        'UPDATE users SET points = points + :change WHERE id = :childId',
        {'change': change, 'childId': childId});
    await conn.execute(
        'INSERT INTO points_records (user_id, grade, level, `change`, reason) '
        'VALUES (:userId, 0, 0, :change, :reason)',
        {
          'userId': childId,
          'change': change,
          'reason': reason,
        });
    await conn.execute(
        'UPDATE handwriting_submissions '
        'SET status = "reviewed", reviewed_by = :reviewer, review_change = :change, reviewed_at = NOW() '
        'WHERE id = :id',
        {
          'reviewer': parent['id'],
          'change': change,
          'id': submissionId,
        });
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
    final res = await conn.execute(
        'SELECT id FROM users WHERE username = :username', {'username': username});
    return res.rows.isNotEmpty;
  });
  if (exists) {
    throw const ApiError(409, '用户名已存在');
  }

  final salt = newSalt();
  final hash = hashPassword(salt, password);
  final id = await Db.withConn((conn) async {
    final res = await conn.execute(
        'INSERT INTO users (username, password_hash, salt, nickname, role, grade, parent_id) '
        'VALUES (:username, :hash, :salt, :nickname, "child", :grade, :parentId)',
        {
          'username': username,
          'hash': hash,
          'salt': salt,
          'nickname': nickname,
          'grade': grade,
          'parentId': parent['id'],
        });
    return res.lastInsertID.toInt();
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
      final res = await conn.execute(
          'SELECT COUNT(*) AS total, SUM(correct = 1) AS correct '
          'FROM records WHERE user_id = :cid',
          {'cid': cid});
      return res.rows;
    });
    final row = rows.first.typedAssoc();
    final total = (row['total'] as num).toInt();
    final correct = (row['correct'] as num).toInt();
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
    final res = await conn.execute(
        'SELECT id, username, nickname, grade FROM users '
        "WHERE id = :childId AND parent_id = :parentId AND role = 'child'",
        {'childId': childId, 'parentId': parent['id']});
    return res.rows;
  });
  if (rows.isEmpty) {
    throw const ApiError(404, '孩子不存在');
  }

  final limit = int.tryParse(ctx.query['limit'] ?? '50')?.clamp(1, 200) ?? 50;
  final records = await Db.withConn((conn) async {
    final res = await conn.execute(
        'SELECT expression, answer, user_answer, correct, mode, grade, created_at '
        'FROM records WHERE user_id = :childId ORDER BY created_at DESC LIMIT :limit',
        {'childId': childId, 'limit': limit});
    return res.rows;
  });

  final childRow = rows.first.typedAssoc();
  return {
    'child': {
      'id': childRow['id'],
      'username': childRow['username'],
      'nickname': childRow['nickname'],
      'grade': childRow['grade'],
    },
    'records': records.map((r) => _recordMap(r.typedAssoc())).toList(),
  };
}
