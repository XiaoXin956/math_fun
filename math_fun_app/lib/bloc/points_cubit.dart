import 'package:bloc/bloc.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../services/session.dart';

/// 积分状态：当前总分 + 积分明细（含来源与加减分理由）。
class PointsState {
  final int total;
  final List<PointsRecord> records;
  final bool loading;

  const PointsState({
    this.total = 0,
    this.records = const [],
    this.loading = false,
  });

  PointsState copy(
      {int? total, List<PointsRecord>? records, bool? loading}) {
    return PointsState(
        total: total ?? this.total,
        records: records ?? this.records,
        loading: loading ?? this.loading);
  }
}

class PointsCubit extends Cubit<PointsState> {
  PointsCubit() : super(const PointsState());

  ApiClient get _client => Session.createClient();

  Future<void> load() async {
    emit(PointsState(loading: true));
    try {
      final res = await _client.get('/api/points');
      emit(PointsState(
          total: res['total'] as int,
          records: (res['records'] as List)
              .map((e) => PointsRecord.fromJson(e as Map<String, dynamic>))
              .toList()));
    } catch (_) {
      emit(const PointsState());
    }
  }
}
