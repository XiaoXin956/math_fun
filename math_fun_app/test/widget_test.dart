// 基础冒烟测试：验证核心数据模型可正确解析。
import 'package:flutter_test/flutter_test.dart';

import 'package:math_fun_app/models/models.dart';

void main() {
  test('User.fromJson parses fields', () {
    final user = User.fromJson({
      'id': 1,
      'username': 'child1',
      'nickname': '小明',
      'role': 'child',
      'grade': 2,
      'parentId': null,
      'points': 10,
    });
    expect(user.id, 1);
    expect(user.nickname, '小明');
    expect(user.isParent, isFalse);
  });
}
