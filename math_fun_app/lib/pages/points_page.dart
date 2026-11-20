import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/points_cubit.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// 积分明细：当前积分 + 每条积分的来源与加减分理由。
class PointsPage extends StatefulWidget {
  static const routeName = '/points';
  const PointsPage({super.key});

  @override
  State<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> {
  @override
  void initState() {
    super.initState();
    // 挂载完成后触发首次加载（initState 中还不能使用 context）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PointsCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🎖️ 积分明细')),
      body: BlocBuilder<PointsCubit, PointsState>(
        builder: (context, state) {
          return SafeArea(
            child: RefreshIndicator(
              onRefresh: () => context.read<PointsCubit>().load(),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppGradients.hero,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        boxShadow: AppShadows.medium,
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.emoji_events_rounded,
                              color: AppColors.star, size: 34),
                          const SizedBox(height: 6),
                          const Text('我的星星积分',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text(
                            '${state.total}',
                            style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '积分来源：闯关结算（≥95% 加 3 分、80%~95% 不变、<80% 扣 3 分）、'
                      '中途退出扣 5 分、手写批改由家长加减分（0~10）',
                      style: TextStyle(fontSize: 12, color: AppColors.inkFaint),
                    ),
                    const SizedBox(height: 20),
                    const Text('积分记录',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: state.loading
                          ? const Center(child: CircularProgressIndicator())
                          : state.records.isEmpty
                              ? const Center(child: Text('暂无积分变动记录'))
                              : ListView.separated(
                                  itemCount: state.records.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (_, i) =>
                                      _card(state.records[i]),
                                ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _card(PointsRecord record) {
    final change = record.change;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: change >= 0
                    ? AppColors.successSoft
                    : AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                change >= 0 ? '+${change}' : '$change',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: change >= 0
                        ? AppColors.success
                        : AppColors.danger),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 积分来源
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          record.sourceLabel,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.star),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (record.levelLabel.isNotEmpty)
                        Text(
                          record.levelLabel,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.inkSoft),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 加减分理由
                  Text(record.reason,
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(record.timeLabel,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.inkFaint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
