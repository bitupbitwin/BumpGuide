import 'package:flutter_test/flutter_test.dart';
import 'package:bumpjourney/models/models.dart';

void main() {
  test('CustomEvent toMap/fromMap 往返一致', () {
    final e = CustomEvent(
      id: 7,
      title: '建档',
      content: '带身份证',
      targetDate: DateTime(2026, 6, 5),
      associatedWeek: 12,
      remindDaysBefore: 3,
      isCompleted: true,
    );
    final back = CustomEvent.fromMap(e.toMap());
    expect(back.id, 7);
    expect(back.title, '建档');
    expect(back.content, '带身份证');
    expect(back.associatedWeek, 12);
    expect(back.remindDaysBefore, 3);
    expect(back.isCompleted, isTrue);
    expect(back.targetDate, e.targetDate);
  });

  test('FetalMovementSession 计算时长并可序列化往返', () {
    final s = FetalMovementSession(
      id: 1,
      startTime: DateTime(2026, 6, 5, 10, 0),
      endTime: DateTime(2026, 6, 5, 11, 0),
      count: 8,
    );
    expect(s.duration, const Duration(hours: 1));
    final back = FetalMovementSession.fromMap(s.toMap());
    expect(back.count, 8);
    expect(back.startTime, s.startTime);
    expect(back.endTime, s.endTime);
  });

  test('胎动记录只按「2 小时内 ≥ 6 次」对照,观察不足不算达标', () {
    FetalCountStatus of(int minutes, int count) => FetalMovementSession(
          startTime: DateTime(2026, 6, 5, 10, 0),
          endTime: DateTime(2026, 6, 5, 10, 0).add(Duration(minutes: minutes)),
          count: count,
        ).status;
    expect(of(40, 6), FetalCountStatus.reached);
    expect(of(120, 6), FetalCountStatus.reached);
    // 审查复现:59 分钟 1 次、180 分钟 6 次以前都显示绿色勾
    expect(of(59, 1), FetalCountStatus.undetermined);
    expect(of(180, 6), FetalCountStatus.undetermined);
    expect(of(120, 5), FetalCountStatus.attention);
    expect(of(150, 0), FetalCountStatus.attention);
    expect(of(30, 0), FetalCountStatus.undetermined);
  });

  test('ContractionRecord 计算时长并可序列化往返', () {
    final c = ContractionRecord(
      id: 1,
      startTime: DateTime(2026, 6, 5, 10, 0, 0),
      endTime: DateTime(2026, 6, 5, 10, 1, 0),
    );
    expect(c.duration, const Duration(minutes: 1));
    final back = ContractionRecord.fromMap(c.toMap());
    expect(back.startTime, c.startTime);
    expect(back.endTime, c.endTime);
  });

  test('WeightRecord 可序列化往返', () {
    final w = WeightRecord(id: 3, date: DateTime(2026, 6, 5), weightKg: 58.5);
    final back = WeightRecord.fromMap(w.toMap());
    expect(back.id, 3);
    expect(back.weightKg, 58.5);
    expect(back.date, w.date);
  });

  test('ChecklistItem 序列化往返 + copyWith 切换勾选', () {
    const c = ChecklistItem(
      id: 5,
      listKey: 'newborn',
      category: '喂养类',
      title: '玻璃奶瓶 120ml',
      qty: '1-2个',
      timing: '产前',
      checked: false,
      sort: 3,
    );
    final back = ChecklistItem.fromMap(c.toMap());
    expect(back.id, 5);
    expect(back.listKey, 'newborn');
    expect(back.category, '喂养类');
    expect(back.title, '玻璃奶瓶 120ml');
    expect(back.qty, '1-2个');
    expect(back.timing, '产前');
    expect(back.sort, 3);
    expect(back.checked, isFalse);
    expect(c.copyWith(checked: true).checked, isTrue);
  });

  test('ChecklistItem 默认 listKey 为 hospital_bag', () {
    const c = ChecklistItem(category: '证件', title: '身份证');
    expect(c.listKey, 'hospital_bag');
    expect(ChecklistItem.fromMap(c.toMap()).listKey, 'hospital_bag');
  });
}
