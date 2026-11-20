import 'dart:math';

/// 按小学年级的算术题目生成器。
///
/// 规则要点：
/// - 所有题目结果与中间过程均为非负整数；
/// - 除法保证整除；
/// - 多步运算渲染时加括号，保证「按书写顺序计算」与答案一致。

enum Op { add, sub, mul, div }

const Map<Op, String> _opSymbol = {
  Op.add: '+',
  Op.sub: '-',
  Op.mul: '×',
  Op.div: '÷',
};

String opSymbol(Op op) => _opSymbol[op]!;

class GradeConfig {
  final int grade;
  final String name;
  final int min;
  final int max;
  final int maxResult;
  final List<Op> ops;
  final int maxOps;

  const GradeConfig({
    required this.grade,
    required this.name,
    required this.min,
    required this.max,
    required this.maxResult,
    required this.ops,
    required this.maxOps,
  });

  bool opAllowed(Op op) => ops.contains(op);
}

/// 一年级：20 以内加减法
/// 二年级：100 以内加减 + 表内乘除
/// 三年级：100 以内四则，两步运算
/// 四年级：500 以内，两步/三步运算
/// 五、六年级：更大范围，三步运算
const List<GradeConfig> gradeConfigs = [
  GradeConfig(grade: 1, name: '一年级', min: 1, max: 20, maxResult: 20,
      ops: [Op.add, Op.sub], maxOps: 1),
  GradeConfig(grade: 2, name: '二年级', min: 1, max: 100, maxResult: 100,
      ops: [Op.add, Op.sub, Op.mul, Op.div], maxOps: 1),
  GradeConfig(grade: 3, name: '三年级', min: 1, max: 200, maxResult: 500,
      ops: [Op.add, Op.sub, Op.mul, Op.div], maxOps: 2),
  GradeConfig(grade: 4, name: '四年级', min: 1, max: 500, maxResult: 2000,
      ops: [Op.add, Op.sub, Op.mul, Op.div], maxOps: 3),
  GradeConfig(grade: 5, name: '五年级', min: 1, max: 1000, maxResult: 10000,
      ops: [Op.add, Op.sub, Op.mul, Op.div], maxOps: 3),
  GradeConfig(grade: 6, name: '六年级', min: 1, max: 2000, maxResult: 20000,
      ops: [Op.add, Op.sub, Op.mul, Op.div], maxOps: 3),
];

/// 数值范围分类：10/20/50/100/1000 以内，与年级并列。
/// 用 101-105 编码，避免与年级 1-6 冲突；全链路（成绩/进度/积分）复用 grade 字段。
/// 运算按范围自动匹配：小数范围只加减，中等范围加表内乘除，1000 以内四则。
const List<GradeConfig> rangeConfigs = [
  GradeConfig(grade: 101, name: '10以内', min: 1, max: 10, maxResult: 10,
      ops: [Op.add, Op.sub], maxOps: 1),
  GradeConfig(grade: 102, name: '20以内', min: 1, max: 20, maxResult: 20,
      ops: [Op.add, Op.sub], maxOps: 1),
  GradeConfig(grade: 103, name: '50以内', min: 1, max: 50, maxResult: 50,
      ops: [Op.add, Op.sub, Op.mul, Op.div], maxOps: 1),
  GradeConfig(grade: 104, name: '100以内', min: 1, max: 100, maxResult: 100,
      ops: [Op.add, Op.sub, Op.mul, Op.div], maxOps: 1),
  GradeConfig(grade: 105, name: '1000以内', min: 1, max: 1000, maxResult: 1000,
      ops: [Op.add, Op.sub, Op.mul, Op.div], maxOps: 2),
];

GradeConfig gradeConfigOf(int grade) {
  for (final c in gradeConfigs) {
    if (c.grade == grade) return c;
  }
  for (final c in rangeConfigs) {
    if (c.grade == grade) return c;
  }
  return const GradeConfig(
      grade: 1, name: '一年级', min: 1, max: 20, maxResult: 20,
      ops: [Op.add, Op.sub], maxOps: 1);
}

final _rnd = Random.secure();

int _randInt(int min, int max) {
  if (max <= min) return min;
  return min + _rnd.nextInt(max - min + 1);
}

Op? _parseOp(String? s) {
  switch (s) {
    case 'add':
      return Op.add;
    case 'sub':
      return Op.sub;
    case 'mul':
      return Op.mul;
    case 'div':
      return Op.div;
    default:
      return null;
  }
}

/// 生成一道题。
///
/// [grade] 年级（1-6），[operation] 可选指定运算（add/sub/mul/div/mixed），
/// [opCountHint] 为正时在年级允许的最大步数上加 1（用于高关卡）。
/// 返回 [(表达式, 答案)]。
(String, int) generateQuestion({
  required int grade,
  String? operation,
  int opCountHint = 0,
}) {
  final cfg = gradeConfigOf(grade);

  List<Op> candidates = cfg.ops;
  final op = _parseOp(operation);
  if (op != null && cfg.opAllowed(op)) {
    candidates = [op];
  }

  final maxSteps = (cfg.maxOps + (opCountHint > 0 ? 1 : 0)).clamp(1, 3);
  final opCount = _randInt(1, maxSteps);

  // 初始值同时留出加法空间（不超答案上限）与乘法空间（不超过上限一半）
  var value = _randInt(
      cfg.min, cfg.max.clamp(cfg.min, (cfg.maxResult / 2).floor()));
  var expression = value.toString();

  var i = 0;
  var retries = 0;
  while (i < opCount && retries < 20) {
    final op2 = candidates[_rnd.nextInt(candidates.length)];

    // 第一步是除法时，用全新数字构造，保证整除且除数在 2..9 内
    if (i == 0 && op2 == Op.div) {
      final d = _randInt(2, 9);
      final qMax = (cfg.maxResult / d).floor().clamp(2, 9);
      final q = _randInt(2, qMax);
      final dividend = d * q;
      expression = '$dividend ÷ $d';
      // 表达式的计算结果是商 q，value 必须同步为 q，否则后续运算会基于被除数出错
      value = q;
      i++;
      retries = 0;
      continue;
    }

    final operand = _makeOperand(op2, cfg, value);
    if (operand == null) {
      // 当前值无法进行该运算，换一个运算重试
      retries++;
      continue;
    }
    retries = 0;
    final symbol = opSymbol(op2);
    value = _apply(op2, value, operand);
    final prefix = i == 0 ? expression : '($expression)';
    expression = '$prefix $symbol $operand';
    i++;
  }

  return (expression, value);
}

/// 计算下一步运算：返回 null 表示当前值无法进行该运算（需换运算）。
int? _makeOperand(Op op, GradeConfig cfg, int value) {
  switch (op) {
    case Op.add:
      final room = cfg.maxResult - value;
      if (room < 1) return null;
      return _randInt(1, room.clamp(1, cfg.max));
    case Op.sub:
      if (value < 1) return null;
      return _randInt(1, value);
    case Op.mul:
      // value 可能为 0（前序减法减到 0），此时不能做乘法，直接换运算
      if (value < 1) return null;
      final room = (cfg.maxResult / value).floor();
      if (room < 2) return null;
      return _randInt(2, room.clamp(2, 9));
    case Op.div:
      return _pickDivisor(value, cfg);
  }
}

int _apply(Op op, int value, int operand) {
  switch (op) {
    case Op.add:
      return value + operand;
    case Op.sub:
      return value - operand;
    case Op.mul:
      return value * operand;
    case Op.div:
      return (value / operand).toInt();
  }
}

/// 在 [2..9] 中选一个能整除 value 的除数，选不到返回 null。
int? _pickDivisor(int value, GradeConfig cfg) {
  final candidates = <int>[];
  for (var d = 2; d <= 9; d++) {
    if (value % d == 0 && d <= cfg.max) {
      candidates.add(d);
    }
  }
  if (candidates.isEmpty) return null;
  return candidates[_rnd.nextInt(candidates.length)];
}

/// 生成一组题目（闯关/限时等需要多题时使用）。
List<(String, int)> generateBatch({
  required int grade,
  String? operation,
  int count = 1,
  int opCountHint = 0,
}) {
  return List.generate(
      count,
      (_) =>
          generateQuestion(grade: grade, operation: operation,
              opCountHint: opCountHint));
}
