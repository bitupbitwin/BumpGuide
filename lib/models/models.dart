/// 内置标准孕周数据(只读预置)
class StandardWeekData {
  final int week;
  final String fruitEmoji;
  final String fetusSummary;
  final String bodyChange;
  final List<String> dietGood;
  final List<String> dietBad;
  final List<CheckItem> checks;
  final List<DadTask> dadTasks;

  // —— 更丰富的每周指导(孕妈) ——
  final List<String> tips; // 本周注意事项 / 提醒
  final String nutrition; // 营养补充重点
  final String exercise; // 运动量 / 运动建议
  final String sleep; // 睡眠姿势 / 禁忌
  final String water; // 喝水量 / 饮水建议

  // —— 准爸爸 ——
  final String dadTip; // 本周体贴提示(随周变化)

  const StandardWeekData({
    required this.week,
    required this.fruitEmoji,
    required this.fetusSummary,
    required this.bodyChange,
    required this.dietGood,
    required this.dietBad,
    required this.checks,
    required this.dadTasks,
    this.tips = const [],
    this.nutrition = '',
    this.exercise = '',
    this.sleep = '',
    this.water = '',
    this.dadTip = '',
  });
}

class CheckItem {
  final String title;
  final String note;
  const CheckItem(this.title, [this.note = '']);
}

class DadTask {
  final String title;
  final bool defaultDone;
  const DadTask(this.title, [this.defaultDone = false]);
}

/// 用户自定义事件(可写,落 SQLite 表 user_custom_events)
class CustomEvent {
  final int? id;
  final String title;
  final String content;
  final DateTime targetDate;
  final int associatedWeek;
  final int remindDaysBefore; // 0=不提醒
  final bool isCompleted;

  const CustomEvent({
    this.id,
    required this.title,
    this.content = '',
    required this.targetDate,
    required this.associatedWeek,
    this.remindDaysBefore = 0,
    this.isCompleted = false,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'event_id': id,
        'title': title,
        'content': content,
        'target_date': targetDate.toIso8601String(),
        'associated_week': associatedWeek,
        'remind_days_before': remindDaysBefore,
        'is_completed': isCompleted ? 1 : 0,
      };

  factory CustomEvent.fromMap(Map<String, Object?> m) => CustomEvent(
        id: m['event_id'] as int?,
        title: m['title'] as String,
        content: (m['content'] as String?) ?? '',
        targetDate: DateTime.parse(m['target_date'] as String),
        associatedWeek: m['associated_week'] as int,
        remindDaysBefore: (m['remind_days_before'] as int?) ?? 0,
        isCompleted: (m['is_completed'] as int? ?? 0) == 1,
      );

  CustomEvent copyWith({int? id, bool? isCompleted}) => CustomEvent(
        id: id ?? this.id,
        title: title,
        content: content,
        targetDate: targetDate,
        associatedWeek: associatedWeek,
        remindDaysBefore: remindDaysBefore,
        isCompleted: isCompleted ?? this.isCompleted,
      );
}

/// 知识库条目(可写,落 SQLite 表 user_knowledge_base)
class KnowledgeItem {
  final int? id;
  final String title;
  final String rawContent; // AI 提炼后或原始文本
  final String sourceUrl;
  final List<String> tags;
  final int? pinnedWeek; // 非空则锚定到对应周时间线

  const KnowledgeItem({
    this.id,
    required this.title,
    this.rawContent = '',
    this.sourceUrl = '',
    this.tags = const [],
    this.pinnedWeek,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'item_id': id,
        'title': title,
        'raw_content': rawContent,
        'source_url': sourceUrl,
        'tags': tags.join(','),
        'pinned_week': pinnedWeek,
      };

  factory KnowledgeItem.fromMap(Map<String, Object?> m) => KnowledgeItem(
        id: m['item_id'] as int?,
        title: m['title'] as String,
        rawContent: (m['raw_content'] as String?) ?? '',
        sourceUrl: (m['source_url'] as String?) ?? '',
        tags: ((m['tags'] as String?) ?? '')
            .split(',')
            .where((e) => e.trim().isNotEmpty)
            .toList(),
        pinnedWeek: m['pinned_week'] as int?,
      );
}

/// 胎动计数对照的口径:2 小时内 ≥ 6 次(与胎动页说明文字一致,改动需两处一起改)
const fetalCountWindow = Duration(hours: 2);
const fetalCountTarget = 6;

enum FetalCountStatus {
  /// 2 小时内已达 6 次
  reached,

  /// 判断不了:未满 2 小时就结束且不足 6 次,或超过 2 小时才数到 6 次、无法确认 2 小时内达标
  undetermined,

  /// 满 2 小时仍不足 6 次
  attention,
}

/// 胎动计数会话(可写,落 SQLite 表 fetal_movement_sessions)。
/// 一次「数胎动」即一条记录:开始/结束时间 + 这段时间内记录的胎动次数。
class FetalMovementSession {
  final int? id;
  final DateTime startTime;
  final DateTime endTime;
  final int count;

  const FetalMovementSession({
    this.id,
    required this.startTime,
    required this.endTime,
    required this.count,
  });

  Duration get duration => endTime.difference(startTime);

  /// 按页面写明的口径「2 小时内 ≥ 6 次」归类。只记次数、不记每次的时刻,
  /// 所以历时超过 2 小时的记录无法确认是否在 2 小时内达标;这只是对照口径,不是健康结论。
  FetalCountStatus get status {
    final enough = count >= fetalCountTarget;
    if (enough && duration <= fetalCountWindow) return FetalCountStatus.reached;
    if (!enough && duration >= fetalCountWindow) return FetalCountStatus.attention;
    return FetalCountStatus.undetermined;
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'fm_id': id,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'count': count,
      };

  factory FetalMovementSession.fromMap(Map<String, Object?> m) =>
      FetalMovementSession(
        id: m['fm_id'] as int?,
        startTime: DateTime.parse(m['start_time'] as String),
        endTime: DateTime.parse(m['end_time'] as String),
        count: (m['count'] as int?) ?? 0,
      );
}

/// 宫缩计时记录(可写,落 SQLite 表 contraction_records)。
/// 每一次宫缩即一条记录;间隔由相邻记录的开始时间推算。
class ContractionRecord {
  final int? id;
  final DateTime startTime;
  final DateTime endTime;

  const ContractionRecord({
    this.id,
    required this.startTime,
    required this.endTime,
  });

  Duration get duration => endTime.difference(startTime);

  Map<String, Object?> toMap() => {
        if (id != null) 'ct_id': id,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
      };

  factory ContractionRecord.fromMap(Map<String, Object?> m) => ContractionRecord(
        id: m['ct_id'] as int?,
        startTime: DateTime.parse(m['start_time'] as String),
        endTime: DateTime.parse(m['end_time'] as String),
      );
}

/// 体重记录(可写,落 SQLite 表 weight_records)。
class WeightRecord {
  final int? id;
  final DateTime date;
  final double weightKg;

  const WeightRecord({
    this.id,
    required this.date,
    required this.weightKg,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'w_id': id,
        'date': date.toIso8601String(),
        'weight': weightKg,
      };

  factory WeightRecord.fromMap(Map<String, Object?> m) => WeightRecord(
        id: m['w_id'] as int?,
        date: DateTime.parse(m['date'] as String),
        weightKg: (m['weight'] as num).toDouble(),
      );
}

/// 清单条目(可写,落 SQLite 表 checklist_items)。
/// 一张表服务多份清单:list_key 区分(hospital_bag 待产包 / newborn 新生儿 / mom 宝妈)。
/// category:子类;qty:建议数量(可空);timing:准备时机标签(产前/月子/3M+/6M+/按需,可空)。
class ChecklistItem {
  final int? id;
  final String listKey;
  final String category;
  final String title;
  final String? qty;
  final String? timing;
  final bool checked;
  final int sort;

  const ChecklistItem({
    this.id,
    this.listKey = 'hospital_bag',
    required this.category,
    required this.title,
    this.qty,
    this.timing,
    this.checked = false,
    this.sort = 0,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'cl_id': id,
        'list_key': listKey,
        'category': category,
        'title': title,
        'qty': qty,
        'timing': timing,
        'is_checked': checked ? 1 : 0,
        'sort': sort,
      };

  factory ChecklistItem.fromMap(Map<String, Object?> m) => ChecklistItem(
        id: m['cl_id'] as int?,
        listKey: (m['list_key'] as String?) ?? 'hospital_bag',
        category: m['category'] as String,
        title: m['title'] as String,
        qty: m['qty'] as String?,
        timing: m['timing'] as String?,
        checked: (m['is_checked'] as int? ?? 0) == 1,
        sort: (m['sort'] as int?) ?? 0,
      );

  ChecklistItem copyWith({bool? checked}) => ChecklistItem(
        id: id,
        listKey: listKey,
        category: category,
        title: title,
        qty: qty,
        timing: timing,
        checked: checked ?? this.checked,
        sort: sort,
      );
}
