import 'handlers.dart';
import 'http_router.dart';

import 'config.dart';
import 'db.dart';

void main() async {
  final config = AppConfig.fromEnv();

  await Db.init(config);
  // ignore: avoid_print
  print('[db] MySQL 连接成功: ${config.dbHost}:${config.dbPort}/${config.dbName}');

  final router = Router(host: config.host, port: config.port);

  // 基础
  router.add('GET', '/', (_) async =>
      {'name': 'math_fun backend', 'status': 'ok', 'docs': '/api/grades'});

  // 认证
  router.add('POST', '/api/auth/register', register);
  router.add('POST', '/api/auth/login', login);
  router.add('POST', '/api/auth/logout', logout);
  router.add('GET', '/api/auth/me', me);

  // 年级配置
  router.add('GET', '/api/grades', (_) async => grades());

  // 题目与判分
  router.add('POST', '/api/questions', generateQuestions);
  router.add('POST', '/api/results', submitResult);
  // 自由练习：一次下发全部题目+答案，本地判分，最后批量上报
  router.add('POST', '/api/practice/questions', practiceQuestions);
  router.add('POST', '/api/practice/results', practiceResults);
  router.add('GET', '/api/practice/daily', practiceDaily);
  router.add('GET', '/api/history', history);
  router.add('GET', '/api/stats', stats);

  // 闯关进度
  router.add('GET', '/api/progress/challenge', challengeProgress);
  router.add('POST', '/api/progress/challenge', completeChallenge);
  router.add('POST', '/api/progress/challenge/quit', quitChallenge);

  // 限时挑战
  router.add('POST', '/api/progress/timed', submitTimed);
  router.add('GET', '/api/progress/timed', timedBest);

  // 积分
  router.add('GET', '/api/points', pointsHistory);

  // 手写答案：孩子提交 / 家长批改
  router.add('POST', '/api/handwriting/submit', submitHandwriting);
  router.add('GET', '/api/handwriting/pending', pendingHandwriting);
  router.add('POST', '/api/handwriting/review', reviewHandwriting);

  // 家长端
  router.add('POST', '/api/children', addChild);
  router.add('GET', '/api/children', listChildren);
  router.add('GET', '/api/children/:id/history', childHistory);

  await router.start();
  // ignore: avoid_print
  print('[server] math_fun backend listening on ${config.host}:${config.port}');
}
