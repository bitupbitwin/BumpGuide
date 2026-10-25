import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';

/// 胎动计数器。孕晚期(约 28 周起)每日早中晚各数 1 小时,
/// 一般 2 小时内胎动 ≥ 6 次为正常;明显减少或异常增多应及时就医。
class FetalMovementScreen extends StatefulWidget {
  const FetalMovementScreen({super.key});
  @override
  State<FetalMovementScreen> createState() => _FetalMovementScreenState();
}

class _FetalMovementScreenState extends State<FetalMovementScreen> {
  DateTime? _start;
  int _count = 0;
  Timer? _ticker;
  bool _saving = false;

  bool get _active => _start != null;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startSession() {
    setState(() {
      _start = DateTime.now();
      _count = 0;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  void _record() {
    if (!_active || _saving) return;
    setState(() => _count++);
  }

  void _clearSession() {
    _ticker?.cancel();
    _ticker = null;
    setState(() {
      _start = null;
      _count = 0;
      _saving = false;
    });
  }

  /// 零次也保存:一次完整观察里没数到胎动,恰恰是最需要留下的记录。
  /// 先存后清,存失败时本次计数还在,可以再点一次。
  Future<void> _endSession() async {
    final start = _start;
    if (start == null || _saving) return;
    setState(() => _saving = true);
    try {
      await context.read<AppState>().addFetalSession(FetalMovementSession(
            startTime: start,
            endTime: DateTime.now(),
            count: _count,
          ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败,本次计数还在,请再点一次「结束并保存」')));
      return;
    }
    if (mounted) _clearSession();
  }

  /// 误点开始时用:明确放弃,不留记录
  Future<void> _discardSession() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃本次计数?'),
        content: Text('本次已数 $_count 次,放弃后不会保存。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('继续计数')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('放弃')),
        ],
      ),
    );
    if (ok == true && mounted && !_saving) _clearSession();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final accent = AppColors.accent(app.role);
    final accentSoft = AppColors.accentSoft(app.role);
    final elapsed = _active ? DateTime.now().difference(_start!) : Duration.zero;

    return Scaffold(
      backgroundColor: AppColors.scaffold(app.role),
      appBar: AppBar(
        title: const Text('胎动计数', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.scaffold(app.role),
        foregroundColor: AppColors.ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
        children: [
          SectionCard(
            background: accentSoft,
            child: const Text(
              '🍼 孕晚期每日早中晚各数 1 小时。一般 2 小时内胎动 ≥ 6 次为正常;'
              '若胎动明显减少、消失或异常频繁,请立即就医。',
              style: TextStyle(fontSize: 13, color: Color(0xFF5C564E), height: 1.7),
            ),
          ),
          // —— 计数主区 ——
          SectionCard(
            child: Column(
              children: [
                Text(_active ? '计时中 · ${_fmtDuration(elapsed)}' : '点击下方开始计数',
                    style: const TextStyle(fontSize: 13, color: AppColors.sub)),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: _active ? _record : _startSession,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _active ? accent : accentSoft,
                      boxShadow: _active ? AppTheme.cardShadow : null,
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_active ? '$_count' : '开始',
                            style: TextStyle(
                                fontSize: _active ? 56 : 30,
                                fontWeight: FontWeight.w900,
                                color: _active ? Colors.white : accent)),
                        if (_active)
                          const Text('次 · 点我 +1',
                              style: TextStyle(fontSize: 13, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (_active)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _saving ? null : _endSession,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        side: BorderSide(color: accent, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('结束并保存',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  ),
                if (_active)
                  TextButton(
                    onPressed: _saving ? null : _discardSession,
                    child: const Text('放弃本次(不保存)',
                        style: TextStyle(fontSize: 13, color: AppColors.sub)),
                  ),
              ],
            ),
          ),
          // —— 历史 ——
          if (app.fetalSessions.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 6, 4, 8),
              child: Text('历史记录',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ),
            ...app.fetalSessions.map((s) => _historyTile(app, s, accent, accentSoft)),
          ],
        ],
      ),
    );
  }

  Widget _historyTile(
      AppState app, FetalMovementSession s, Color accent, Color accentSoft) {
    // 只对照「2 小时内 ≥ 6 次」这条口径,不替任何一次记录下「正常」结论
    final (IconData icon, Color color, String note) = switch (s.status) {
      FetalCountStatus.reached => (Icons.check_circle_outline, AppColors.good, '2 小时内已达 6 次'),
      FetalCountStatus.attention => (Icons.info_outline, AppColors.bad, '满 2 小时不足 6 次,请留意,明显减少请就医'),
      FetalCountStatus.undetermined => (
          Icons.hourglass_empty,
          AppColors.sub,
          s.count >= fetalCountTarget ? '超过 2 小时,无法确认 2 小时内是否达 6 次' : '未满 2 小时,还不能按 2 小时 6 次对照'
        ),
    };
    return Dismissible(
      key: ValueKey('fm_${s.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24, bottom: 14),
        child: const Icon(Icons.delete_outline, color: AppColors.bad),
      ),
      onDismissed: (_) => app.deleteFetalSession(s.id!),
      child: SectionCard(
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: accentSoft, borderRadius: BorderRadius.circular(14)),
              alignment: Alignment.center,
              child: Text('${s.count}',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900, color: accent)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_fmtDate(s.startTime)} ${_fmtTime(s.startTime)}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('计数 ${s.count} 次 · 历时 ${_fmtDuration(s.duration)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                  const SizedBox(height: 2),
                  Text(note, style: TextStyle(fontSize: 11, color: color)),
                ],
              ),
            ),
            Icon(icon, size: 20, color: color),
          ],
        ),
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');
String _fmtTime(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';
String _fmtDate(DateTime t) => '${_two(t.month)}-${_two(t.day)}';
String _fmtDuration(Duration d) {
  if (d.inHours > 0) return '${d.inHours}小时${d.inMinutes % 60}分';
  if (d.inMinutes > 0) return '${d.inMinutes}分${d.inSeconds % 60}秒';
  return '${d.inSeconds}秒';
}
