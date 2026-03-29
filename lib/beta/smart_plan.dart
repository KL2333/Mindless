// lib/beta/smart_plan.dart
// ─────────────────────────────────────────────────────────────────────────────
// 智能建议 v5 — 屏幕使用 × 任务统计 深度联动分析
//
// 新增维度（在 v4 的11维基础上扩展）：
//   13. 屏幕娱乐时段分布 × 任务完成时段（今日/历史）
//   14. 专注时长 vs 单类 App 使用时长对比（打扰源精准定位）
//   15. 高娱乐日 vs 低娱乐日任务完成率对比（历史 UsageLog）
//   16. 专注质量评估（短专注 + 娱乐高 → "碎片化陷阱"）
//   17. 今日 AI 辅助工具使用情况分析（工作类 App）
//   18. 综合健康指数 HPI（Health Productivity Index）
//
// 设计原则：
//   • 屏幕数据仅今日实时（UsageSummary），历史联动靠 AppState 任务数据推算
//   • 建议文字精准 < 35 字，避免啰嗦
//   • 每条洞察只说一件事，不堆砌
// ─────────────────────────────────────────────────────────────────────────────

import '../models/models.dart';
import '../services/pom_deep_analysis.dart';
import '../providers/app_state.dart';
import '../l10n/l10n.dart';
import 'usage_stats_service.dart';

class BlockSuggestion {
  final String taskId;
  final String suggestedBlock;
  final String reason;
  const BlockSuggestion({required this.taskId, required this.suggestedBlock,
      required this.reason});
}

enum Confidence { low, medium, high }

class Insight {
  final String icon;
  final String title;
  final String body;
  final Confidence confidence;
  // NEW: 来源标记，供 UI 分组展示
  final InsightSource source;
  const Insight({
    required this.icon, required this.title, required this.body,
    this.confidence = Confidence.medium,
    this.source = InsightSource.task,
  });
}

/// 洞察来源：UI 可按此分组或标色
enum InsightSource {
  task,        // 纯任务统计类
  screen,      // 纯屏幕使用类
  crossTask,   // 任务×任务交叉（标签/时段/命名模式）
  crossScreen, // 任务×屏幕交叉（核心新功能）
  trend,       // 趋势类
  deepFocus,   // 番茄钟深度分析交叉
  environment, // 环境声 × 专注质量
}

class DaySuggestion {
  final String summary;
  final List<BlockSuggestion> moves;
  final String focus;
  final List<Insight> insights;
  final String loadWarning;
  final String trendLabel;
  // Screen
  final String? screenSummary;
  final int?    screenEffScore;
  final String? topDistractionApp;
  // NEW: 综合健康指数
  final int?    hpi;           // 0-100
  final String? hpiLabel;      // 文字描述
  // 心流指数洞察
  final String? flowInsight;

  const DaySuggestion({
    required this.summary, required this.moves, required this.focus,
    this.insights = const [], this.loadWarning = '', this.trendLabel = '',
    this.screenSummary, this.screenEffScore, this.topDistractionApp,
    this.hpi, this.hpiLabel, this.flowInsight,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// 命名模式枚举（8类，与 v4 一致）
// ─────────────────────────────────────────────────────────────────────────────
enum NamePattern {
  code, physics, medicine, lang_study, daily_cn, task_verb, mixed, unknown,
}

class _NameProfile {
  final NamePattern pattern;
  final double avgFocusSecs;
  final int count;
  final String example;
  const _NameProfile({required this.pattern, required this.avgFocusSecs,
      required this.count, required this.example});
}

class _CrossInsight {
  final String title;
  final String body;
  final Confidence confidence;
  final InsightSource source;
  const _CrossInsight({required this.title, required this.body,
      required this.confidence, this.source = InsightSource.crossTask});
}

// ═══════════════════════════════════════════════════════════════════════════
// 词典（与 v4 一致，保留完整）
// ═══════════════════════════════════════════════════════════════════════════
const _kPhysicsTerms = {
  '牛顿','力学','动力学','运动学','静力学','摩擦','加速度','速度','位移',
  '动量','冲量','功','能量','守恒','碰撞','转动','扭矩','角速度',
  '热力学','温度','热量','比热','熵','卡诺','理想气体','热膨胀','传热',
  '热传导','辐射','对流','焓','亥姆霍兹','吉布斯',
  '电磁','电场','磁场','电荷','电势','电容','电感','电阻','欧姆',
  '法拉第','麦克斯韦','电流','电压','功率','交流','直流','电路','电磁波',
  '楞次','库仑','高斯','安培','毕萨定律',
  '光学','几何光学','波动光学','反射','折射','衍射','干涉','偏振','透镜',
  '棱镜','光速','折射率','色散','光谱','激光','光子',
  '量子','波函数','薛定谔','海森堡','不确定性','光电效应','玻尔','原子',
  '核裂变','核聚变','相对论','洛伦兹','质能','时空','黑体辐射',
  '振动','波动','简谐','共振','驻波','频率','波长','周期','振幅',
};
const _kMedicineTerms = {
  '解剖','生理','病理','生化','微生物','免疫','药理','组织','胚胎',
  '遗传','病理生理','法医','寄生虫',
  '内科','外科','妇科','儿科','神经科','精神科','皮肤科','眼科',
  '耳鼻喉','口腔','骨科','泌尿','肿瘤','心脏','呼吸','消化','血液',
  '内分泌','风湿','传染','急诊','重症','麻醉','影像','检验',
  '诊断','症状','体征','病史','查体','鉴别','治疗','预后','护理',
  '病例','病案','手术','并发症','适应症','禁忌症',
  '用药','剂量','副作用','抗生素','抗炎','降压','降糖','利尿',
  '抗凝','镇痛','镇静','激素','维生素',
  '西医','中医','执医','规培','考研','病理学','内科学','外科学',
};
const _kLangStudyTerms = {
  '单词','词汇','生词','背词','记词','语法','句型','句式','阅读',
  '听力','口语','写作','翻译','词组','短语','俚语','成语',
  '背诵','默写','朗读','听写','精读','泛读','速读','精听','泛听',
  '跟读','复述','口译','笔译',
  '英语','日语','法语','德语','西班牙','韩语','俄语','意大利',
  '汉语','普通话','粤语','闽南',
  '四级','六级','雅思','托福','托业','gre','gmat','sat','toefl',
  'ielts','delf','jlpt','hsk',
};
const _kDailyCnTerms = {
  '打扫','洗碗','做饭','洗衣','整理','清洁','收拾','晾晒','倒垃圾',
  '联系','回复','发邮件','打电话','通话','见面','约饭','聚餐',
  '拜访','慰问',
  '购物','买菜','缴费','报销','取快递','预约','挂号','就医',
  '缴税','办理','续费','充值',
  '运动','跑步','健身','瑜伽','散步','骑车','游泳','冥想','睡觉',
};
const _kTaskVerbPrefixes = {
  '写','撰写','起草','编写','记录','填写','回复','发送','提交',
  '复习','预习','学习','练习','刷题','做题','背','记','看','读',
  '整理','归纳','总结','梳理','分类','归档','更新','整合',
  '做','完成','处理','解决','跟进','确认','检查','审核','验证',
  '规划','计划','安排','准备','制定','设计','思考','研究','调查',
};

class SmartPlan {

  // ═══════════════════════════════════════════════════════════════════════════
  // 主入口
  // ═══════════════════════════════════════════════════════════════════════════
  static DaySuggestion suggest(AppState state, {UsageSummary? usage, String? noiseInsight, String? flowInsight}) {
    final today = state.todayKey;
    final days30 = _pastDays(today, 30);
    final days14 = _pastDays(today, 14);
    final days7  = _pastDays(today, 7);

    // ── 维度 1: 活力节律 ─────────────────────────────────────────────────
    final vit30 = state.vitalityData(days30);
    final total30 = (vit30['morning']??0)+(vit30['afternoon']??0)+(vit30['evening']??0);
    String bestBlk = 'morning', worstBlk = 'evening';
    if (total30 > 0) {
      bestBlk  = vit30.entries.reduce((a,b) => a.value >= b.value ? a : b).key;
      worstBlk = vit30.entries.reduce((a,b) => a.value <= b.value ? a : b).key;
    }

    // ── 维度 2: 完成率 per block ─────────────────────────────────────────
    final rates = <String, double>{};
    for (final blk in ['morning','afternoon','evening']) {
      final planned = state.tasks.where((t) =>
          t.originalTimeBlock == blk && days14.contains(t.originalDate)).length;
      final done = state.tasks.where((t) =>
          t.originalTimeBlock == blk && t.done && days14.contains(t.doneAt)).length;
      rates[blk] = planned > 0 ? done / planned : 0.5;
    }
    final lowRateBlk = rates.entries.reduce((a,b) => a.value <= b.value ? a : b).key;

    // ── 维度 3: 系统性偏差 ───────────────────────────────────────────────
    double totalDev = 0; int devCount = 0;
    for (final t in state.tasks) {
      if (!t.done || t.doneAt == null || t.originalTimeBlock == 'unassigned') continue;
      if (!days30.contains(t.doneAt)) continue;
      final aBlk = t.doneTimeBlock ?? (t.doneHour != null
          ? AppState.hourToTimeBlock(t.doneHour!, 0) : null);
      if (aBlk == null) continue;
      totalDev += (_blkIdx(aBlk) - _blkIdx(t.originalTimeBlock)).toDouble();
      devCount++;
    }
    final avgDev = devCount > 0 ? totalDev / devCount : 0.0;

    // ── 维度 4: 专注深度 ─────────────────────────────────────────────────
    final withFocus = state.tasks.where((t) => t.done && t.focusSecs > 60).toList();
    final avgFocusSecs = withFocus.isEmpty ? 0.0
        : withFocus.fold(0,(s,t) => s+t.focusSecs) / withFocus.length;

    // ── 维度 5: 标签负载 ─────────────────────────────────────────────────
    final pendingByTag = <String,int>{};
    for (final t in state.tasks) {
      if (t.done || t.ignored) continue;
      for (final tag in t.tags) pendingByTag[tag] = (pendingByTag[tag]??0)+1;
    }
    final heaviestTag = pendingByTag.isEmpty ? null
        : pendingByTag.entries.reduce((a,b) => a.value >= b.value ? a : b).key;

    // ── 维度 6: 逾期雪球 ─────────────────────────────────────────────────
    final overdue = state.tasks.where((t) =>
        !t.done && !t.ignored && t.originalDate.compareTo(today) < 0).toList();
    final overdueScore = overdue.fold(0.0, (s,t) =>
        s + DateTime.now().difference(DateTime.parse('${t.originalDate}T12:00:00')).inDays);

    // ── 维度 7: 周期规律 ─────────────────────────────────────────────────
    String? strongDay, weakDay;
    if (total30 >= 10) {
      final byWd = <int,int>{};
      for (final t in state.tasks) {
        if (!t.done || !days30.contains(t.doneAt)) continue;
        final wd = DateTime.parse('${t.doneAt}T12:00:00').weekday;
        byWd[wd] = (byWd[wd]??0)+1;
      }
      if (byWd.length >= 3) {
        strongDay = _wdName(byWd.entries.reduce((a,b) => a.value >= b.value ? a : b).key);
        weakDay   = _wdName(byWd.entries.reduce((a,b) => a.value <= b.value ? a : b).key);
      }
    }

    // ── 维度 8: 近7天趋势 ────────────────────────────────────────────────
    final done7 = days7.map((d) => state.doneOnDay(d)).toList();
    String trendLabel = '';
    if (done7.length >= 5) {
      final fh = done7.take(3).fold(0,(a,b)=>a+b);
      final lh = done7.skip(4).fold(0,(a,b)=>a+b);
      if (lh > fh+1)      trendLabel = L.get('screens.today.smartPlan.trendUp');
      else if (fh > lh+1) trendLabel = L.get('screens.today.smartPlan.trendDown');
    }

    // ── 维度 9: 命名模式 ─────────────────────────────────────────────────
    final nameProfiles = _analyzeNamePatterns(state.tasks);

    // ── 维度 10: 标签×时段交叉 ──────────────────────────────────────────
    final tagBlockCross = _crossTagBlock(state.tasks, days30);

    // ── 维度 11: 命名×专注时长交叉 ──────────────────────────────────────
    final nameTimeCross = _crossNameFocus(state.tasks);

    // ── 维度 12-18: 屏幕使用深度分析 ───────────────────────────────────
    String? screenSummary;
    int? screenEffScore;
    String? topDistractionApp;
    final screenInsights = <_CrossInsight>[];
    final focusSecs = state.todayFocusSecs();

    if (usage != null) {
      final entertainH = usage.totalEntertainMs / 3600000;
      final focusH = focusSecs / 3600;
      screenEffScore = usage.efficiencyScore(focusSecs);

      // 12a: 今日总结语
      final distraction = usage.apps
          .where((a) => a.type != 'other' && a.type != 'work')
          .fold<AppUsageEntry?>(null, (prev, cur) =>
              prev == null || cur.ms > prev.ms ? cur : prev);
      topDistractionApp = distraction?.appName;

      if (entertainH > focusH * 2 && entertainH > 1.0) {
        screenSummary = L.get('screens.today.smartPlan.screenSummaryTooMuchEntertainment', {
          'entertain': entertainH.toStringAsFixed(1),
          'focus': focusH.toStringAsFixed(1),
        });
      } else if (entertainH > focusH && entertainH > 0.5) {
        screenSummary = L.get('screens.today.smartPlan.screenSummarySlightlyMoreEntertainment', {
          'entertain': entertainH.toStringAsFixed(1),
          'focus': focusH.toStringAsFixed(1),
        });
      } else if (focusH > entertainH * 1.5 && focusH > 0.5) {
        screenSummary = L.get('screens.today.smartPlan.screenSummaryGreatFocus', {
          'entertain': entertainH.toStringAsFixed(1),
          'focus': focusH.toStringAsFixed(1),
        });
      } else if (entertainH == 0 && focusH > 0) {
        screenSummary = L.get('screens.today.smartPlan.screenSummaryZeroEntertainment', {
          'focus': focusH.toStringAsFixed(1),
        });
      }

      // ── 维度 13: 屏幕类别分布分析 ────────────────────────────────────
      final catMs = {
        'game': usage.totalGameMs,
        'video': usage.totalVideoMs,
        'social': usage.totalSocialMs,
        'music': usage.totalMusicMs,
        'news': usage.totalNewsMs,
        'shopping': usage.totalShoppingMs,
        'custom': usage.totalCustomMs,
        'work': usage.totalWorkMs,
      };
      final topCats = catMs.entries
          .where((e) => e.value > 5 * 60000) // >5分钟才算
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // 最大娱乐类型精准定位
      final entertainCats = topCats.where(
          (e) => e.key != 'work' && e.key != 'music').toList();
      if (entertainCats.isNotEmpty) {
        final topCat = entertainCats.first;
        final topMin = (topCat.value / 60000).round();
        final advice = _catAdvice(topCat.key, bestBlk, worstBlk);
        screenInsights.add(_CrossInsight(
          title: L.get('screens.today.smartPlan.insights.topUsageTitle', {
            'cat': _catLabel(topCat.key),
            'mins': topMin.toString(),
          }),
          body: advice,
          confidence: topMin > 90 ? Confidence.high : Confidence.medium,
          source: InsightSource.screen,
        ));
      }

      // ── 维度 14: 专注时长 vs 单 App 时长对比 ─────────────────────────
      if (distraction != null) {
        final distractMin = (distraction.ms / 60000).round();
        final focusMin = (focusSecs / 60).round();
        if (distractMin > 0 && focusMin > 0) {
          final ratio = distractMin / focusMin;
          if (ratio > 1.5) {
            screenInsights.add(_CrossInsight(
              title: L.get('screens.today.smartPlan.insights.appVsFocusWorseTitle', {
                'app': distraction.appName, 'appMins': distractMin.toString(),
                'focusMins': focusMin.toString(),
              }),
              body: L.get('screens.today.smartPlan.insights.appVsFocusWorseBody', {
                'block': _blkName(bestBlk), 'app': distraction.appName,
              }),
              confidence: ratio > 2 ? Confidence.high : Confidence.medium,
              source: InsightSource.crossScreen,
            ));
          } else if (ratio < 0.3 && focusMin > 30) {
            screenInsights.add(_CrossInsight(
              title: L.get('screens.today.smartPlan.insights.appVsFocusGoodTitle', {
                'focusMins': focusMin.toString(), 'appMins': distractMin.toString(),
              }),
              body: L.get('screens.today.smartPlan.insights.appVsFocusGoodBody'),
              confidence: Confidence.medium,
              source: InsightSource.crossScreen,
            ));
          }
        }
      }

      // ── 维度 16: 专注质量评估（碎片化陷阱检测）─────────────────────
      // 短专注（均 < 15min）+ 高娱乐 → 碎片化陷阱
      if (avgFocusSecs > 0 && avgFocusSecs < 15 * 60 &&
          entertainH > 0.5 && withFocus.length >= 3) {
        screenInsights.add(_CrossInsight(
          title: L.get('screens.today.smartPlan.insights.fragmentTrapTitle', {
            'focusAvg': ((avgFocusSecs/60).round()).toString(),
            'entertainH': entertainH.toStringAsFixed(1),
          }),
          body: L.get('screens.today.smartPlan.insights.fragmentTrapBody', {
            'app': (distraction?.appName ?? L.get('screens.today.smartPlan.insights.entertainmentApp')),
          }),
          confidence: Confidence.high,
          source: InsightSource.crossScreen,
        ));
      }

      // ── 维度 17: AI/工作类 App 使用分析 ─────────────────────────────
      if (usage.totalWorkMs > 10 * 60000) {
        final workMin = (usage.totalWorkMs / 60000).round();
        final workApps = usage.apps
            .where((a) => a.type == 'work')
            .toList()
          ..sort((a, b) => b.ms.compareTo(a.ms));
        if (workApps.isNotEmpty) {
          final topWork = workApps.first;
          final topWorkMin = (topWork.ms / 60000).round();
          // 工作类 App 使用时间 > 专注番茄时间，说明在工具 App 里而不在任务里
          if (topWorkMin > (focusSecs / 60) * 1.5 && focusSecs > 0) {
            screenInsights.add(_CrossInsight(
              title: L.get('screens.today.smartPlan.insights.workAppMoreThanFocusTitle', {
                'app': topWork.appName,
                'appMins': topWorkMin.toString(),
                'focusMins': ((focusSecs/60).round()).toString(),
              }),
              body: L.get('screens.today.smartPlan.insights.workAppMoreThanFocusBody'),
              confidence: Confidence.medium,
              source: InsightSource.crossScreen,
            ));
          } else if (workMin > 20) {
            screenInsights.add(_CrossInsight(
              title: L.get('screens.today.smartPlan.insights.workAppsTodayTitle', {
                'mins': workMin.toString()
              }),
              body: workApps.length > 1
                  ? L.get('screens.today.smartPlan.insights.workAppsTodayBodyMulti', {
                      'apps': workApps.take(2).map((a) => a.appName).join(' / ')
                    })
                  : L.get('screens.today.smartPlan.insights.workAppsTodayBodySingle', {
                      'app': topWork.appName
                    }),
              confidence: Confidence.low,
              source: InsightSource.screen,
            ));
          }
        }
      }

      // ── 维度 15: 历史推算 — 高娱乐日 vs 低娱乐日完成率 ─────────────
      // 由于没有历史 UsageSummary，用今日数据结合任务完成率做实时判断：
      // 今日完成率 = 今日已完成 / 今日总任务
      final todayPending = state.tasks.where((t) =>
          !t.done && !t.ignored &&
          (t.createdAt == today || t.rescheduledTo == today)).length;
      final todayDone = state.doneOnDay(today);
      final todayTotal = todayPending + todayDone;
      final todayRate = todayTotal > 0 ? todayDone / todayTotal : -1.0;

      if (todayRate >= 0 && entertainH > 0) {
        // 与近7天均值对比
        final avgDoneDay = days7.isEmpty ? 0.0
            : days7.fold(0, (s, d) => s + state.doneOnDay(d)) / days7.length;
        if (todayRate < 0.4 && entertainH > 1.5) {
          screenInsights.add(_CrossInsight(
            title: L.get('screens.today.smartPlan.insights.lowRateHighEntertainmentTitle', {
              'rate': ((todayRate*100).round()).toString(),
              'entertainH': entertainH.toStringAsFixed(1),
            }),
            body: L.get('screens.today.smartPlan.insights.lowRateHighEntertainmentBody', {
              'block': _blkName(worstBlk)
            }),
            confidence: Confidence.high,
            source: InsightSource.crossScreen,
          ));
        } else if (todayDone > avgDoneDay * 1.3 && entertainH < 0.5) {
          screenInsights.add(_CrossInsight(
            title: L.get('screens.today.smartPlan.insights.lowEntertainmentValidationTitle', {
              'done': todayDone.toString(),
              'avg': avgDoneDay.toStringAsFixed(1),
            }),
            body: L.get('screens.today.smartPlan.insights.lowEntertainmentValidationBody'),
            confidence: Confidence.high,
            source: InsightSource.crossScreen,
          ));
        }
      }

      // ── 维度 18: 综合健康指数 HPI ─────────────────────────────────────
      // 已在下方计算
    }

    // ── 任务量预警 ───────────────────────────────────────────────────────
    final todayPending = state.tasks.where((t) =>
        !t.done && !t.ignored &&
        (t.createdAt == today || t.rescheduledTo == today)).length;
    final availH = state.settings.disposableHours;
    final avgFocusH = avgFocusSecs > 0 ? avgFocusSecs / 3600 : 25.0/60;
    final estH = todayPending * avgFocusH;
    String loadWarning = '';
    if (todayPending > 0 && availH > 0) {
      if (estH > availH * 1.3) {
        loadWarning = L.get('screens.today.smartPlan.loadWarning.overload', {
          'estH': estH.toStringAsFixed(1),
          'availH': availH.toString(),
          'remove': (todayPending - availH/avgFocusH).ceil().toString(),
        });
      } else if (estH < availH * 0.5) {
        loadWarning = L.get('screens.today.smartPlan.loadWarning.underload', {
          'mins': ((estH*60).round()).toString(),
        });
      }
    }

    // ── 任务分配建议 ─────────────────────────────────────────────────────
    // Include ALL undone non-ignored tasks (not just today) for one-tap scheduling
    final unassigned = state.tasks.where((t) =>
        !t.done && !t.ignored &&
        (t.timeBlock == 'unassigned' || t.timeBlock == '')).toList();

    final moves = <BlockSuggestion>[];
    for (final t in unassigned) {
      final isQ1 = t.quadrant == 1;
      final isQ4 = t.quadrant == 4;
      final isOverdue = t.originalDate.compareTo(today) < 0;
      final namePat = classifyName(t.text);
      final overdueDays = isOverdue
          ? DateTime.now().difference(DateTime.parse('${t.originalDate}T12:00:00')).inDays
          : 0;

      String? suggestBlk;
      String? reason;

      if (isOverdue || isQ1) {
        suggestBlk = bestBlk;
        reason = isOverdue
            ? '逾期 $overdueDays 天，安排在${_blkName(bestBlk)}（效率峰值）'
            : '重要紧急，匹配效率峰值${_blkName(bestBlk)}';
      } else if (_isDeepWorkPattern(namePat) && nameTimeCross != null) {
        final avgSecs = nameTimeCross[namePat.name] ?? 0.0;
        if (avgSecs > 35 * 60) {
          suggestBlk = bestBlk;
          reason = '${_patternLabel(namePat)}任务历史均需 ${(avgSecs/60).round()}分钟，'
              '安排在${_blkName(bestBlk)}确保专注';
        }
      } else if (!isQ1 && !isOverdue) {
        final bestBlkForTag = t.tags.isNotEmpty
            ? _bestBlockForTag(tagBlockCross, t.tags.first)
            : null;
        if (isQ4 || bestBlkForTag == null) {
          suggestBlk = worstBlk;
          reason = '轻量任务放${_blkName(worstBlk)}，黄金时段留给重要工作';
        } else {
          suggestBlk = bestBlkForTag;
          reason = '「${t.tags.first}」在${_blkName(bestBlkForTag)}完成率最高';
        }
      }

      if (suggestBlk != null && reason != null) {
        moves.add(BlockSuggestion(taskId: t.id.toString(),
            suggestedBlock: suggestBlk, reason: reason));
      }
    }

    // ── 洞察列表组装 ─────────────────────────────────────────────────────
    final insights = <Insight>[];

    // Task-based insights (v4 原有)
    if (total30 >= 7) {
      insights.add(Insight(
        icon: '⚡',
        title: L.get('screens.today.smartPlan.insights.peakBlockTitle', {'block': _blkName(bestBlk)}),
        body: L.get('screens.today.smartPlan.insights.peakBlockBody', {
          'bestBlock': _blkName(bestBlk),
          'bestCount': (vit30[bestBlk] ?? 0).toString(),
          'worstBlock': _blkName(worstBlk),
          'worstCount': (vit30[worstBlk] ?? 0).toString(),
          'ratio': (vit30[worstBlk]! > 0 ? (vit30[bestBlk]!/vit30[worstBlk]!).toStringAsFixed(1) : '∞'),
        }),
        confidence: total30 >= 20 ? Confidence.high : Confidence.medium,
        source: InsightSource.task,
      ));
    }

    if (devCount >= 5 && avgDev.abs() > 0.5) {
      insights.add(Insight(
        icon: avgDev > 0 ? '🕐' : '🚀',
        title: avgDev > 0
            ? L.get('screens.today.smartPlan.insights.systemDelayTitle', {'delta': avgDev.toStringAsFixed(1)})
            : L.get('screens.today.smartPlan.insights.systemAdvanceTitle', {'delta': avgDev.abs().toStringAsFixed(1)}),
        body: avgDev > 0
            ? L.get('screens.today.smartPlan.insights.systemDelayBody')
            : L.get('screens.today.smartPlan.insights.systemAdvanceBody'),
        confidence: devCount >= 15 ? Confidence.high : Confidence.medium,
        source: InsightSource.task,
      ));
    }

    if (total30 >= 7) {
      final lowRate = (rates[lowRateBlk]! * 100).round();
      insights.add(Insight(
        icon: '📉',
        title: L.get('screens.today.smartPlan.insights.lowestRateTitle', {
          'block': _blkName(lowRateBlk), 'rate': lowRate.toString(),
        }),
        body: lowRate < 50
            ? L.get('screens.today.smartPlan.insights.lowestRateBodyLow')
            : L.get('screens.today.smartPlan.insights.lowestRateBodyMove', {
                'block': _blkName(bestBlk)
              }),
        confidence: lowRate < 40 ? Confidence.high : Confidence.medium,
        source: InsightSource.task,
      ));
    }

    if (withFocus.length >= 5) {
      final avgMin = (avgFocusSecs/60).round();
      insights.add(Insight(
        icon: '🎯',
        title: L.get('screens.today.smartPlan.insights.avgFocusTitle', {'mins': avgMin.toString()}),
        body: avgFocusSecs >= 25*60
            ? L.get('screens.today.smartPlan.insights.avgFocusGood')
            : avgFocusSecs >= 15*60
                ? L.get('screens.today.smartPlan.insights.avgFocusMedium')
                : L.get('screens.today.smartPlan.insights.avgFocusShort'),
        confidence: withFocus.length >= 15 ? Confidence.high : Confidence.medium,
        source: InsightSource.task,
      ));
    }

    if (overdue.isNotEmpty) {
      insights.add(Insight(
        icon: '❄️',
        title: L.get('screens.today.smartPlan.insights.overdueTitle', {
          'count': overdue.length.toString(),
          'days': overdueScore.round().toString(),
        }),
        body: overdueScore > 14
            ? L.get('screens.today.smartPlan.insights.overdueBodyHeavy', {'block': _blkName(bestBlk)})
            : L.get('screens.today.smartPlan.insights.overdueBodyLight', {'block': _blkName(bestBlk)}),
        confidence: Confidence.high,
        source: InsightSource.task,
      ));
    }

    // 交叉洞察（任务×任务）
    final crossInsights = _buildCrossInsights(
        tagBlockCross, nameProfiles, nameTimeCross, state.tags, total30);
    for (final ci in crossInsights) {
      insights.add(Insight(icon: '🔗', title: ci.title, body: ci.body,
          confidence: ci.confidence, source: ci.source));
    }

    if (heaviestTag != null && (pendingByTag[heaviestTag]! >= 3)) {
      insights.add(Insight(
        icon: '🏷',
        title: L.get('screens.today.smartPlan.insights.tagBacklogTitle', {
          'tag': heaviestTag,
          'count': (pendingByTag[heaviestTag] ?? 0).toString(),
        }),
        body: L.get('screens.today.smartPlan.insights.tagBacklogBody'),
        confidence: Confidence.medium, source: InsightSource.task,
      ));
    }

    if (strongDay != null && weakDay != null) {
      insights.add(Insight(
        icon: '📅',
        title: L.get('screens.today.smartPlan.insights.weekdayEfficiencyTitle', {
          'best': strongDay, 'worst': weakDay,
        }),
        body: L.get('screens.today.smartPlan.insights.weekdayEfficiencyBody', {
          'best': strongDay, 'worst': weakDay,
        }),
        confidence: Confidence.medium, source: InsightSource.task,
      ));
    }

    if (trendLabel.isNotEmpty) {
      insights.add(Insight(
        icon: trendLabel.contains('上升') ? '📈' : '📉',
        title: trendLabel,
        body: trendLabel.contains('上升')
            ? L.get('screens.today.smartPlan.insights.trendUpBody')
            : L.get('screens.today.smartPlan.insights.trendDownBody'),
        confidence: Confidence.medium, source: InsightSource.trend,
      ));
    }

    // 习惯追踪洞察
    final habitInsights = analyzeHabits(state);
    insights.addAll(habitInsights);

    // 屏幕使用洞察（v4 原有 + v5 新增交叉洞察合并）
    if (usage != null) {
      final entertainH = usage.totalEntertainMs / 3600000;
      final focusH = focusSecs / 3600;
      final effScore = usage.efficiencyScore(focusSecs);

      // v4 基础屏幕洞察
      if (entertainH > 0.3) {
        final cats = <String>[];
        if (usage.totalSocialMs > 0) cats.add(L.get('screens.today.smartPlan.insights.catLine', {
          'cat': _catLabel('social'), 'mins': ((usage.totalSocialMs/60000).round()).toString()
        }));
        if (usage.totalVideoMs > 0)  cats.add(L.get('screens.today.smartPlan.insights.catLine', {
          'cat': _catLabel('video'), 'mins': ((usage.totalVideoMs/60000).round()).toString()
        }));
        if (usage.totalGameMs > 0)   cats.add(L.get('screens.today.smartPlan.insights.catLine', {
          'cat': _catLabel('game'), 'mins': ((usage.totalGameMs/60000).round()).toString()
        }));
        if (usage.totalMusicMs > 0)  cats.add(L.get('screens.today.smartPlan.insights.catLine', {
          'cat': _catLabel('music'), 'mins': ((usage.totalMusicMs/60000).round()).toString()
        }));
        if (usage.totalNewsMs > 0)   cats.add(L.get('screens.today.smartPlan.insights.catLine', {
          'cat': _catLabel('news'), 'mins': ((usage.totalNewsMs/60000).round()).toString()
        }));
        if (usage.totalCustomMs > 0) cats.add(L.get('screens.today.smartPlan.insights.catLine', {
          'cat': _catLabel('custom'), 'mins': ((usage.totalCustomMs/60000).round()).toString()
        }));
        final catStr = cats.take(3).join('、');

        final icon = effScore >= 70 ? '✅' : effScore >= 40 ? '⚠️' : '🚨';
        String body;
        if (catStr.isNotEmpty) {
          final label = effScore >= 70
              ? L.get('screens.today.smartPlan.insights.screenEfficiencyJudgementHigh')
              : effScore >= 40
                  ? L.get('screens.today.smartPlan.insights.screenEfficiencyJudgementMedium')
                  : L.get('screens.today.smartPlan.insights.screenEfficiencyJudgementLow');
          body = L.get('screens.today.smartPlan.insights.screenEfficiencyBodyWithCats', {
            'cats': catStr, 'label': label,
          });
        } else {
          body = L.get('screens.today.smartPlan.insights.screenEfficiencyBodyNoCats', {
            'entertainMins': ((entertainH*60).round()).toString(),
            'focusMins': ((focusH*60).round()).toString(),
          });
        }

        insights.add(Insight(
          icon: icon,
          title: L.get('screens.today.smartPlan.insights.screenEfficiencyTitle', {
            'score': effScore.toString(),
          }),
          body: body,
          confidence: effScore < 40 ? Confidence.high
              : effScore < 70 ? Confidence.medium : Confidence.medium,
          source: InsightSource.screen,
        ));
      }

      // 专注/娱乐比
      if (focusH > 0 && entertainH > 0) {
        final ratio = focusH / entertainH;
        if (ratio < 0.5) {
          insights.add(Insight(
            icon: '⚖️',
            title: L.get('screens.today.smartPlan.insights.focusEntertainmentLowTitle', {
              'ratio': ratio.toStringAsFixed(1),
            }),
            body: L.get('screens.today.smartPlan.insights.focusEntertainmentLowBody', {
              'block': _blkName(bestBlk)
            }),
            confidence: Confidence.high, source: InsightSource.screen,
          ));
        } else if (ratio >= 2.0) {
          insights.add(Insight(
            icon: '🏆',
            title: L.get('screens.today.smartPlan.insights.focusEntertainmentGoodTitle', {
              'ratio': ratio.toStringAsFixed(1),
            }),
            body: L.get('screens.today.smartPlan.insights.focusEntertainmentGoodBody'),
            confidence: Confidence.medium, source: InsightSource.screen,
          ));
        }
      }

      // v5 新增：屏幕×任务交叉洞察（置于最高优先级位置）
      for (final si in screenInsights.take(4)) {
        insights.insert(
          // 交叉洞察插入到第3条之后（效率峰值、偏差之后）
          insights.length.clamp(2, insights.length),
          Insight(
            icon: si.source == InsightSource.crossScreen ? '🔀'
                : si.source == InsightSource.screen ? '📱' : '🔗',
            title: si.title, body: si.body,
            confidence: si.confidence, source: si.source,
          ),
        );
      }
    }

    // ── 维度 18: 综合健康指数 HPI ─────────────────────────────────────────
    // 指标组合：任务完成率(30%) + 专注深度(25%) + 趋势(20%) + 屏幕(25%)
    int? hpi;
    String? hpiLabel;
    if (total30 >= 5) {
      // 完成率分
      final avgRate = rates.values.fold(0.0, (a,b) => a+b) / 3;
      final rateScore = (avgRate * 100).clamp(0, 100);
      // 专注深度分
      final focusScore = avgFocusSecs >= 25*60 ? 100.0
          : avgFocusSecs >= 15*60 ? 70.0
          : avgFocusSecs >= 5*60 ? 40.0 : 20.0;
      // 趋势分
      final trendScore = trendLabel.contains('上升') ? 80.0
          : trendLabel.contains('下滑') ? 30.0 : 55.0;
      // 屏幕分
      final screenScore = screenEffScore?.toDouble() ?? 60.0;

      hpi = (rateScore * 0.30 + focusScore * 0.25 +
             trendScore * 0.20 + screenScore * 0.25).round().clamp(0, 100);
      hpiLabel = hpi >= 80 ? '状态极佳 🚀'
               : hpi >= 65 ? '良好 ✅'
               : hpi >= 45 ? '一般 ⚡'
               : '需改善 ⚠️';
    }

    final summary = total30 < 5
        ? L.get('screens.today.smartPlan.insights.summaryAccumulating', {'count': total30.toString()})
        : L.get('screens.today.smartPlan.insights.summaryFull', {
            'count': total30.toString(),
            'bestBlock': _blkName(bestBlk),
            'delay': avgDev > 0.5 ? L.get('screens.today.smartPlan.insights.summaryDelay') :
                    avgDev < -0.5 ? L.get('screens.today.smartPlan.insights.summaryAdvance') :
                    L.get('screens.today.smartPlan.insights.summaryAccurate'),
            'overdue': overdue.isNotEmpty
                ? L.get('screens.today.smartPlan.insights.summaryOverdue', {'count': overdue.length.toString()})
                : '',
            'hpi': hpi != null ? ' HPI $hpi/100' : '',
          });

    // ── 维度 N+1: 番茄钟深度分析交叉 ─────────────────────────────────────
    final deepReport = PomDeepAnalysis.analyze(state);
    if (deepReport.sampleCount >= 3) {
      // Best focus hour vs current task scheduling
      final bestH = deepReport.bestHour;
      final peakBlk = bestH < 12 ? 'morning' : bestH < 18 ? 'afternoon' : 'evening';
      if (peakBlk != bestBlk && deepReport.sampleCount >= 5) {
        insights.add(Insight(
          icon: '⏰',
          title: L.get('screens.today.smartPlan.insights.deepPeakTitle', {
            'hour': _hourShort(bestH)
          }),
          body: L.get('screens.today.smartPlan.insights.deepPeakBody', {
            'label': deepReport.peakLabel,
            'block': _blkName(bestBlk),
          }),
          confidence: Confidence.high,
          source: InsightSource.deepFocus,
        ));
      }
      // Continuity insight
      insights.add(Insight(
        icon: '📈',
        title: L.get('screens.today.smartPlan.insights.continuityTitle'),
        body: deepReport.continuityInsight,
        confidence: Confidence.medium,
        source: InsightSource.deepFocus,
      ));
      // Suggested focus duration vs current setting
      final curMins = state.settings.pom.focusMins;
      if ((deepReport.suggestedFocusMins - curMins).abs() >= 5) {
        final diff = deepReport.suggestedFocusMins > curMins
            ? L.get('screens.today.smartPlan.insights.extend')
            : L.get('screens.today.smartPlan.insights.shorten');
        insights.add(Insight(
          icon: '🍅',
          title: L.get('screens.today.smartPlan.insights.adjustFocusTitle', {'how': diff}),
          body: L.get('screens.today.smartPlan.insights.adjustFocusBody', {
            'samples': deepReport.sampleCount.toString(),
            'from': curMins.toString(),
            'to': deepReport.suggestedFocusMins.toString(),
          }),
          confidence: Confidence.medium,
          source: InsightSource.deepFocus,
        ));
      }
    }

    // ── 维度 N+2: 环境声联动 ──────────────────────────────────────────────
    if (noiseInsight != null && noiseInsight.isNotEmpty) {
      final isNoisy = noiseInsight.contains('嘈杂') || noiseInsight.contains('噪音偏高');
      insights.add(Insight(
        icon: isNoisy ? '🔊' : '🤫',
        title: isNoisy ? '环境噪音影响专注' : '专注环境良好',
        body: noiseInsight,
        confidence: Confidence.medium,
        source: InsightSource.environment,
      ));
      // Also factor noise into HPI adjustment (noisy env -5 pts)
      if (hpi != null && isNoisy) {
        hpi = (hpi - 5).clamp(0, 100);
      }
    }

    return DaySuggestion(
      summary: summary, moves: moves, focus: lowRateBlk,
      insights: insights, loadWarning: loadWarning, trendLabel: trendLabel,
      screenSummary: screenSummary,
      screenEffScore: screenEffScore,
      topDistractionApp: topDistractionApp,
      hpi: hpi, hpiLabel: hpiLabel,
      flowInsight: flowInsight,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 专注时间估算
  // ═══════════════════════════════════════════════════════════════════════════
  // ═══════════════════════════════════════════════════════════════════════
  // 可支配时长多维度估算
  // 基于：历史完成量、专注时长、娱乐占比（可选）
  // ═══════════════════════════════════════════════════════════════════════
  static Map<String, dynamic> estimateDisposableHours(AppState state,
      {UsageSummary? usage}) {
    final today = state.todayKey;
    final days14 = _pastDays(today, 14);
    final days7  = _pastDays(today, 7);

    // 历史每日有效专注时间（中位数）
    final dailyFocusHours = days14.map((d) {
      final tf = state.tasks.where((t) => t.done && t.doneAt == d)
          .fold(0, (s, t) => s + t.focusSecs);
      final uf = state.settings.unboundFocusByDate[d] ?? 0;
      return (tf + uf) / 3600.0;
    }).toList()..sort();
    final medianFocus = dailyFocusHours.isEmpty ? 0.0
        : dailyFocusHours[dailyFocusHours.length ~/ 2];

    // 历史每日完成任务数
    final avgDone = days7.isEmpty ? 0.0
        : days7.fold(0, (s, d) => s + state.doneOnDay(d)) / days7.length;

    // 平均每任务专注时长（分钟）
    final avgMinsPerTask = _avgFocusSecs(state) / 60;

    // 估算：做完均值任务量需要多少小时
    final estFromTasks = avgDone * avgMinsPerTask / 60;

    // 屏幕使用：如果有数据，考虑娱乐占比
    double entertainRatio = 0.0;
    double suggestedFocusRatio = 0.65; // 默认65%可支配时间用于专注
    if (usage != null) {
      final totalScreenH = (usage.totalEntertainMs + usage.totalWorkMs) / 3600000;
      final focusH = state.todayFocusSecs() / 3600;
      if (totalScreenH > 0.5) {
        entertainRatio = usage.totalEntertainMs / 3600000 / totalScreenH;
        // 娱乐比越高，建议专注比稍低（避免过度压缩）
        suggestedFocusRatio = (1.0 - entertainRatio * 0.4).clamp(0.5, 0.8);
      }
    }

    // 综合建议可支配时长 = max(历史均值专注 / 专注比, 基于任务量估算)
    final fromHistory = medianFocus > 0 ? medianFocus / suggestedFocusRatio : 0.0;
    final fromTaskLoad = estFromTasks > 0 ? estFromTasks / suggestedFocusRatio : 0.0;
    final suggested = [fromHistory, fromTaskLoad, 4.0].reduce((a, b) => a > b ? a : b);
    final rounded = (suggested * 2).round() / 2.0; // 0.5步进

    return {
      'suggested': rounded.clamp(1.0, 16.0),
      'medianFocusH': medianFocus,
      'avgDone': avgDone,
      'focusRatio': suggestedFocusRatio,
      'entertainRatio': entertainRatio,
      'reason': medianFocus > 0
          ? '基于近14天均专注 ${medianFocus.toStringAsFixed(1)}h/天，'
            '建议专注占可支配时间 ${(suggestedFocusRatio * 100).round()}%'
          : '暂无历史数据，使用默认值',
    };
  }

  static String estimateFocusNeeded(AppState state) {
    final today = state.todayKey;
    final pending = state.tasks.where((t) =>
        !t.done && !t.ignored &&
        (t.createdAt == today || t.rescheduledTo == today)).length;
    if (pending == 0) return '今日无待办 ✓';
    final avg = _avgFocusSecs(state);
    final estMins = (pending * avg / 60).round();
    if (estMins < 30) return '预计 < 30 分钟专注时间';
    final h = estMins ~/ 60; final m = estMins % 60;
    return '预计需 ${h>0?"${h}h ":""}${m>0?"${m}m":""} 专注（$pending 件，均 ${(avg/60).round()}m/件）';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 命名模式分类（8类，public 供 UI 使用）
  // ═══════════════════════════════════════════════════════════════════════════
  static NamePattern classifyName(String text) {
    final t = text.trim();
    if (t.isEmpty) return NamePattern.unknown;
    final codeReg = RegExp(r'^[\d\s\-_\.#\+\/\\]+$');
    final digits = t.runes.where((r) => r >= 48 && r <= 57).length;
    final digitRatio = digits / t.length;
    if (codeReg.hasMatch(t) || digitRatio > 0.45) return NamePattern.code;
    if (RegExp(r'^[A-Za-z0-9\-_]+$').hasMatch(t) && t.length <= 6) {
      return NamePattern.code;
    }
    final lower = t.toLowerCase();
    final tokens = t.split(RegExp(r'[\s，。、·\-_／/]+'));
    for (final tok in tokens) { if (_kPhysicsTerms.contains(tok)) return NamePattern.physics; }
    if (_kPhysicsTerms.any((term) => t.contains(term))) return NamePattern.physics;
    for (final tok in tokens) { if (_kMedicineTerms.contains(tok)) return NamePattern.medicine; }
    if (_kMedicineTerms.any((term) => t.contains(term))) return NamePattern.medicine;
    for (final tok in tokens) {
      if (_kLangStudyTerms.contains(tok) ||
          _kLangStudyTerms.contains(tok.toLowerCase())) return NamePattern.lang_study;
    }
    if (_kLangStudyTerms.any((term) => lower.contains(term))) return NamePattern.lang_study;
    for (final tok in tokens) { if (_kDailyCnTerms.contains(tok)) return NamePattern.daily_cn; }
    if (_kDailyCnTerms.any((term) => t.contains(term))) return NamePattern.daily_cn;
    for (final prefix in _kTaskVerbPrefixes) {
      if (t.startsWith(prefix)) return NamePattern.task_verb;
    }
    final hasChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(t);
    final hasEnglish = RegExp(r'[A-Za-z]').hasMatch(t);
    if (hasChinese && hasEnglish) return NamePattern.mixed;
    if (hasChinese && digitRatio > 0.1) return NamePattern.mixed;
    return NamePattern.unknown;
  }

  static String _patternLabel(NamePattern p) {
    switch (p) {
      case NamePattern.code:       return '编码式';
      case NamePattern.physics:    return '物理学科';
      case NamePattern.medicine:   return '医学学科';
      case NamePattern.lang_study: return '语言学习';
      case NamePattern.daily_cn:   return '日常生活';
      case NamePattern.task_verb:  return '任务动词';
      case NamePattern.mixed:      return '混合式';
      case NamePattern.unknown:    return '其他';
    }
  }

  static bool _isDeepWorkPattern(NamePattern p) =>
      p == NamePattern.code || p == NamePattern.physics ||
      p == NamePattern.medicine || p == NamePattern.lang_study;

  // ─── 命名模式分布 ────────────────────────────────────────────────────────
  static Map<NamePattern, _NameProfile> _analyzeNamePatterns(List<TaskModel> tasks) {
    final groups = <NamePattern, List<TaskModel>>{};
    for (final t in tasks) {
      if (!t.done || t.focusSecs < 60) continue;
      groups.putIfAbsent(classifyName(t.text), () => []).add(t);
    }
    final result = <NamePattern, _NameProfile>{};
    for (final entry in groups.entries) {
      final ts = entry.value;
      final avg = ts.fold(0,(s,t) => s+t.focusSecs) / ts.length;
      result[entry.key] = _NameProfile(
        pattern: entry.key, avgFocusSecs: avg.toDouble(),
        count: ts.length, example: ts.last.text,
      );
    }
    return result;
  }

  // ─── 标签×时段交叉 ──────────────────────────────────────────────────────
  static Map<String, Map<String, double>> _crossTagBlock(
      List<TaskModel> tasks, List<String> days) {
    final s = days.toSet();
    final doneCnt  = <String, Map<String, int>>{};
    final planCnt  = <String, Map<String, int>>{};
    for (final t in tasks) {
      if (!t.done || !s.contains(t.doneAt)) continue;
      for (final tag in t.tags) {
        final blk = t.doneTimeBlock ?? (t.doneHour != null
            ? AppState.hourToTimeBlock(t.doneHour!, 0) : null);
        if (blk == null) continue;
        doneCnt.putIfAbsent(tag, () => {});
        doneCnt[tag]![blk] = (doneCnt[tag]![blk] ?? 0) + 1;
      }
    }
    for (final t in tasks) {
      if (!s.contains(t.originalDate)) continue;
      if (t.originalTimeBlock == 'unassigned') continue;
      for (final tag in t.tags) {
        planCnt.putIfAbsent(tag, () => {});
        planCnt[tag]![t.originalTimeBlock] =
            (planCnt[tag]![t.originalTimeBlock] ?? 0) + 1;
      }
    }
    final rates = <String, Map<String, double>>{};
    for (final tag in doneCnt.keys) {
      rates[tag] = {};
      for (final blk in ['morning','afternoon','evening']) {
        final done = doneCnt[tag]![blk] ?? 0;
        final plan = planCnt[tag]?[blk] ?? 0;
        rates[tag]![blk] = plan > 0 ? done / plan : 0.0;
      }
    }
    return rates;
  }

  static String? _bestBlockForTag(
      Map<String, Map<String, double>> cross, String tag) {
    final tagRates = cross[tag];
    if (tagRates == null) return null;
    final valid = tagRates.entries.where((e) => e.value > 0).toList();
    if (valid.isEmpty) return null;
    return valid.reduce((a,b) => a.value >= b.value ? a : b).key;
  }

  // ─── 命名×专注时长交叉 ───────────────────────────────────────────────────
  static Map<String, double>? _crossNameFocus(List<TaskModel> tasks) {
    final buckets = <String, List<int>>{};
    for (final pat in NamePattern.values) buckets[pat.name] = [];
    for (final t in tasks) {
      if (!t.done || t.focusSecs < 60) continue;
      buckets[classifyName(t.text).name]!.add(t.focusSecs);
    }
    final hasData = buckets.values.any((v) => v.length >= 3);
    if (!hasData) return null;
    return buckets.map((k, v) =>
        MapEntry(k, v.isEmpty ? 0.0 : v.fold(0,(a,b)=>a+b) / v.length));
  }

  // ─── 交叉洞察生成（任务×任务） ──────────────────────────────────────────
  static List<_CrossInsight> _buildCrossInsights(
      Map<String, Map<String, double>> tagBlock,
      Map<NamePattern, _NameProfile> nameProfiles,
      Map<String, double>? nameTimeCross,
      List<String> allTags,
      int total30) {
    final result = <_CrossInsight>[];

    // A：标签×时段
    if (total30 >= 10 && tagBlock.isNotEmpty) {
      for (final tag in allTags.take(4)) {
        final tagRates = tagBlock[tag];
        if (tagRates == null) continue;
        final valid = tagRates.entries.where((e) => e.value > 0.3).toList();
        if (valid.isEmpty) continue;
        final best = valid.reduce((a,b) => a.value >= b.value ? a : b);
        final pct = (best.value * 100).round();
        if (pct >= 60) {
          result.add(_CrossInsight(
            title: '「$tag」在${_blkName(best.key)}完成率 $pct%',
            body: '「$tag」类任务安排在${_blkName(best.key)}完成率最高，建议优先放这个时段。',
            confidence: pct >= 80 ? Confidence.high : Confidence.medium,
          ));
          if (result.length >= 2) break;
        }
      }
    }

    // B：命名模式×专注时长
    if (nameTimeCross != null) {
      final validPatterns = NamePattern.values
          .where((p) => (nameProfiles[p]?.count ?? 0) >= 3).toList();

      if (validPatterns.length >= 2) {
        validPatterns.sort((a, b) =>
            (nameTimeCross[b.name] ?? 0.0).compareTo(nameTimeCross[a.name] ?? 0.0));
        final longest = validPatterns.first;
        final shortest = validPatterns.last;
        final longAvg = nameTimeCross[longest.name] ?? 0.0;
        final shortAvg = nameTimeCross[shortest.name] ?? 0.0;
        final diff = ((longAvg - shortAvg) / 60).round();
        if (diff >= 8) {
          result.add(_CrossInsight(
            title: '${_patternLabel(longest)}任务比${_patternLabel(shortest)}多专注 $diff 分钟',
            body: '${_patternLabel(longest)}（均 ${(longAvg/60).round()}分钟）需深度投入，'
                '建议整块时间安排；'
                '${_patternLabel(shortest)}（均 ${(shortAvg/60).round()}分钟）可碎片化处理。',
            confidence: (nameProfiles[longest]?.count ?? 0) >= 10
                ? Confidence.high : Confidence.medium,
          ));
        }
      }

      int added = 0;
      for (final pat in NamePattern.values) {
        final prof = nameProfiles[pat];
        if (prof == null || prof.count < 3) continue;
        final avgMin = (prof.avgFocusSecs / 60).round();
        String advice;
        if (prof.avgFocusSecs >= 45 * 60) {
          advice = '深度工作类，建议安排在效率峰值时段，留 1-2 小时整块时间。';
        } else if (prof.avgFocusSecs >= 25 * 60) {
          advice = '中等深度，一个标准番茄钟（25分钟）基本够用。';
        } else {
          advice = '耗时短，可批量集中处理，减少上下文切换成本。';
        }
        result.add(_CrossInsight(
          title: '${_patternLabel(pat)}命名任务均 $avgMin 分钟（${prof.count}件样本）',
          body: '代表性例子：「${prof.example}」。$advice',
          confidence: prof.count >= 10 ? Confidence.high : Confidence.medium,
        ));
        if (++added >= 3) break;
      }
    }

    return result.take(4).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 工具方法
  // ═══════════════════════════════════════════════════════════════════════════
  static double _avgFocusSecs(AppState state) {
    final wf = state.tasks.where((t) => t.done && t.focusSecs > 60).toList();
    return wf.isEmpty ? 25*60 : wf.fold(0,(s,t)=>s+t.focusSecs) / wf.length;
  }
  static List<String> _pastDays(String today, int n) =>
      List.generate(n, (i) => DateUtils2.addDays(today, -(n-1-i)));
  static int _blkIdx(String blk) {
    switch (blk) { case 'morning': return 0; case 'afternoon': return 1; default: return 2; }
  }
  static String _hourShort(int h) {
    if (h < 6)  return '凌晨${h}点';
    if (h < 12) return '上午${h}点';
    if (h == 12) return '正午';
    if (h < 18) return '下午${h - 12}点';
    return '晚上${h - 12}点';
  }

  static String _blkName(String blk) {
    switch (blk) {
      case 'morning': return L.smartPlanMorning;
      case 'afternoon': return L.smartPlanAfternoon;
      default: return L.smartPlanEvening;
    }
  }
  static String _wdName(int wd) =>
      ['','周一','周二','周三','周四','周五','周六','周日'][wd.clamp(0,7)];

  static String _catLabel(String key) {
    switch (key) {
      case 'game': return L.get('screens.today.smartPlan.cat.game');
      case 'video': return L.get('screens.today.smartPlan.cat.video');
      case 'social': return L.get('screens.today.smartPlan.cat.social');
      case 'music': return L.get('screens.today.smartPlan.cat.music');
      case 'news': return L.get('screens.today.smartPlan.cat.news');
      case 'shopping': return L.get('screens.today.smartPlan.cat.shopping');
      case 'work': return L.get('screens.today.smartPlan.cat.work');
      case 'custom': return L.get('screens.today.smartPlan.cat.custom');
      default: return key;
    }
  }

  static String _catAdvice(String key, String bestBlk, String worstBlk) {
    switch (key) {
      case 'game':
        return L.get('screens.today.smartPlan.insights.catAdvice.game', {'bestBlock': _blkName(bestBlk)});
      case 'video':
        return L.get('screens.today.smartPlan.insights.catAdvice.video');
      case 'social':
        return L.get('screens.today.smartPlan.insights.catAdvice.social');
      case 'news':
        return L.get('screens.today.smartPlan.insights.catAdvice.news');
      case 'shopping':
        return L.get('screens.today.smartPlan.insights.catAdvice.shopping', {'worstBlock': _blkName(worstBlk)});
      default:
        return L.get('screens.today.smartPlan.insights.catAdvice.default', {
          'cat': _catLabel(key), 'block': _blkName(worstBlk)
        });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 习惯追踪与智能建议
  // ═══════════════════════════════════════════════════════════════════════
  static List<Insight> analyzeHabits(AppState state) {
    final today = state.todayKey;
    final days30 = _pastDays(today, 30);
    final days14 = _pastDays(today, 14);
    final insights = <Insight>[];

    // 统计每个任务文本出现的频率（去标点，小写化）
    final textFreq = <String, int>{};
    final textLastSeen = <String, String>{};
    final textBestBlock = <String, String>{};

    for (final t in state.tasks) {
      if (!t.done || t.doneAt == null) continue;
      if (!days30.contains(t.doneAt!)) continue;
      final key = _habitKey(t.text);
      if (key.length < 2) continue;
      textFreq[key] = (textFreq[key] ?? 0) + 1;
      if (textLastSeen[key] == null ||
          t.doneAt!.compareTo(textLastSeen[key]!) > 0) {
        textLastSeen[key] = t.doneAt!;
        textBestBlock[key] = t.doneTimeBlock ?? t.timeBlock;
      }
    }

    // 查找高频任务（30天内≥5次 = 习惯阈值）
    final habits = textFreq.entries.where((e) => e.value >= 5).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 今日已有的任务文本
    final todayTexts = state.tasks
        .where((t) => !t.done && !t.ignored &&
            (t.createdAt == today || t.rescheduledTo == today))
        .map((t) => _habitKey(t.text))
        .toSet();

    // 今日已完成的习惯
    final todayDoneTexts = state.tasks
        .where((t) => t.done && t.doneAt == today)
        .map((t) => _habitKey(t.text))
        .toSet();

    for (final habit in habits.take(5)) {
      final key = habit.key;
      final freq = habit.value;
      final bestBlock = textBestBlock[key] ?? 'afternoon';
      final lastSeen = textLastSeen[key] ?? today;
      final blockName = _blkName(bestBlock);

      // 已在今日计划或已完成 → 跳过
      if (todayTexts.contains(key) || todayDoneTexts.contains(key)) continue;

      // 计算连续天数
      int streak = 0;
      for (final d in _pastDays(today, 14).reversed) {
        final doneThat = state.tasks.any((t) =>
            t.done && t.doneAt == d && _habitKey(t.text) == key);
        if (doneThat) streak++; else break;
      }

      final originalText = state.tasks
          .lastWhere((t) => t.done && _habitKey(t.text) == key,
              orElse: () => state.tasks.first)
          .text;

      String body;
      if (streak >= 7) {
        body = '您已连续 $streak 天坚持「$originalText」，今日还未安排。'
            '建议在$blockName（您完成率最高的时段）继续这个好习惯。';
      } else if (freq >= 10) {
        body = '「$originalText」在过去30天内出现 $freq 次，是您的常规习惯。'
            '今日还未安排，建议放在$blockName完成。';
      } else {
        body = '「$originalText」在近30天重复出现 $freq 次。'
            '今日还未见到，是否需要安排在$blockName？';
      }

      insights.add(Insight(
        icon: streak >= 7 ? '🔥' : '📅',
        title: streak >= 7
            ? '习惯连续 $streak 天：$originalText'
            : '习惯追踪：$originalText（$freq 次/月）',
        body: body,
        confidence: freq >= 10 ? Confidence.high : Confidence.medium,
        source: InsightSource.task,
      ));
    }

    // 检测今日任务量少但有习惯未安排的情况
    final todayPending = state.tasks.where((t) =>
        !t.done && !t.ignored &&
        (t.createdAt == today || t.rescheduledTo == today)).length;
    final missedHabits = habits.where((h) =>
        !todayTexts.contains(h.key) &&
        !todayDoneTexts.contains(h.key)).length;

    if (todayPending == 0 && missedHabits > 0) {
      // 今日无任务，主动推荐习惯
      final topHabit = habits.first;
      final topText = state.tasks
          .lastWhere((t) => t.done && _habitKey(t.text) == topHabit.key,
              orElse: () => state.tasks.first)
          .text;
      final bestBlock = textBestBlock[topHabit.key] ?? 'afternoon';
      final blockName = const {
        'morning': '上午', 'afternoon': '下午', 'evening': '晚上',
      }[bestBlock] ?? '下午';
      final vit = state.vitalityData(_pastDays(today, 30));
      final bestVitBlock = vit.entries
          .reduce((a, b) => a.value >= b.value ? a : b).key;
      final bestVitName = const {
        'morning': '上午', 'afternoon': '下午', 'evening': '晚上',
      }[bestVitBlock] ?? '下午';

      insights.add(Insight(
        icon: '💡',
        title: L.get('screens.today.smartPlan.insights.noTasksTitle'),
        body: L.get('screens.today.smartPlan.insights.noTasksBody', {
          'habit': topText,
          'block': bestVitName,
        }),
        confidence: Confidence.high,
        source: InsightSource.trend,
      ));
    }

    return insights;
  }

  static String _habitKey(String text) {
    // 标准化：去标点、空格、取前12字符作为习惯标识
    final cleaned = text
        .replaceAll(RegExp(r'[^\u4e00-\u9fff\w]'), '')
        .toLowerCase();
    if (cleaned.isEmpty) {
      final t = text.trim();
      return t.isEmpty ? '' : t.substring(0, t.length < 8 ? t.length : 8);
    }
    return cleaned.substring(0, cleaned.length < 12 ? cleaned.length : 12);
  }
} // end SmartPlan

// ═══════════════════════════════════════════════════════════════════════════
// 心理学分析层（v6 新增）
// 基于行为心理学 + 认知心理学模型，对用户数据进行深层解读
// ═══════════════════════════════════════════════════════════════════════════

class PsychProfile {
  // 拖延倾向指数 0-100（越高越倾向拖延）
  final int procrastinationIndex;
  // 主要认知负荷模式
  final String cognitivePattern;
  // 自我效能感评估
  final String selfEfficacy;
  // 主要心理洞察列表
  final List<String> insights;
  // 行为建议（基于心理学）
  final List<String> recommendations;

  const PsychProfile({
    required this.procrastinationIndex,
    required this.cognitivePattern,
    required this.selfEfficacy,
    required this.insights,
    required this.recommendations,
  });
}

class PsychAnalyzer {
  /// 对 AppState 所有数据进行心理学分析
  static PsychProfile analyze(AppState state) {
    final today = state.todayKey;
    final days30 = _SmartUtils.pastDays(today, 30);
    final days14 = _SmartUtils.pastDays(today, 14);
    final allTasks = state.tasks;

    // ── 1. 拖延倾向分析 ──────────────────────────────────────────────────
    // 基于「完成时间偏差」「逾期率」「重新安排次数」综合计算
    int procrastScore = 0;

    // 逾期率
    final due14 = allTasks.where((t) =>
        days14.contains(t.originalDate) && !t.ignored).length;
    final overdue14 = allTasks.where((t) =>
        days14.contains(t.originalDate) && !t.done && !t.ignored &&
        t.originalDate.compareTo(today) < 0).length;
    final overdueRate = due14 > 0 ? overdue14 / due14 : 0.0;
    procrastScore += (overdueRate * 30).round();

    // 系统性延后（晚于计划完成）
    int lateCount = 0; int deviationTaskCount = 0;
    for (final t in allTasks) {
      if (!t.done || t.doneAt == null || !days30.contains(t.doneAt)) continue;
      if (t.originalTimeBlock == 'unassigned') continue;
      final actual = t.doneTimeBlock ?? (t.doneHour != null
          ? AppState.hourToTimeBlock(t.doneHour!, 0) : null);
      if (actual == null) continue;
      deviationTaskCount++;
      final bi = {'morning': 0, 'afternoon': 1, 'evening': 2};
      if ((bi[actual] ?? 0) > (bi[t.originalTimeBlock] ?? 0)) lateCount++;
    }
    if (deviationTaskCount >= 5) {
      procrastScore += ((lateCount / deviationTaskCount) * 25).round();
    }

    // 忽略率（主动放弃）
    final ignoredCount = allTasks.where((t) => t.ignored).length;
    final totalCreated = allTasks.length;
    final ignoreRate = totalCreated > 0 ? ignoredCount / totalCreated : 0.0;
    if (ignoreRate > 0.1) procrastScore += (ignoreRate * 20).round().clamp(0, 15);

    // 任务重新安排次数（reschedule）
    final rescheduleCount = allTasks.where((t) => t.rescheduledTo != null).length;
    if (totalCreated > 0) {
      procrastScore += ((rescheduleCount / totalCreated) * 25).round().clamp(0, 20);
    }

    procrastScore = procrastScore.clamp(0, 100);

    // ── 2. 认知负荷模式 ──────────────────────────────────────────────────
    // 基于任务类型分布、专注时长、完成量波动
    String cognitivePattern;
    final avgDailyDone = days14.isEmpty ? 0.0
        : days14.fold(0, (s, d) => s + state.doneOnDay(d)) / days14.length;
    final doneVariance = days14.isEmpty ? 0.0
        : days14.map((d) => (state.doneOnDay(d) - avgDailyDone).abs()).fold(0.0, (a, b) => a + b) / days14.length;

    String cogCode;
    if (doneVariance > avgDailyDone * 0.8 && avgDailyDone > 1) {
      cogCode = 'burstStall';
    } else if (avgDailyDone >= 3 && doneVariance < avgDailyDone * 0.4) {
      cogCode = 'stable';
    } else if (avgDailyDone < 1.5) {
      cogCode = 'lowStart';
    } else {
      cogCode = 'fluctuating';
    }
    cognitivePattern = L.get('screens.today.smartPlan.psych.cognitive.$cogCode');

    // ── 3. 自我效能感 ────────────────────────────────────────────────────
    // Bandura: 近期成功经验 × 任务完成连续性
    final recentDone = days14.where((d) => state.doneOnDay(d) > 0).length;
    final continuityRate = days14.isEmpty ? 0.0 : recentDone / days14.length;
    String selfEfficacy;
    if (continuityRate >= 0.8) selfEfficacy = L.get('screens.today.smartPlan.psych.selfEfficacy.high');
    else if (continuityRate >= 0.5) selfEfficacy = L.get('screens.today.smartPlan.psych.selfEfficacy.medium');
    else if (recentDone == 0) selfEfficacy = L.get('screens.today.smartPlan.psych.selfEfficacy.toActivate');
    else selfEfficacy = L.get('screens.today.smartPlan.psych.selfEfficacy.low');

    // ── 4. 心理洞察组装 ──────────────────────────────────────────────────
    final insights = <String>[];
    final recommendations = <String>[];

    // 拖延心理
    if (procrastScore >= 60) {
      insights.add(L.get('screens.today.smartPlan.psych.procrastination.highInsight', {'score': procrastScore.toString()}));
      recommendations.add(L.get('screens.today.smartPlan.psych.recommendations.twoMinuteRule'));
      recommendations.add(L.get('screens.today.smartPlan.psych.recommendations.splitOverdue'));
    } else if (procrastScore >= 35) {
      insights.add(L.get('screens.today.smartPlan.psych.procrastination.midInsight', {'score': procrastScore.toString()}));
      recommendations.add(L.get('screens.today.smartPlan.psych.recommendations.scheduleHardInPeak'));
    } else {
      insights.add(L.get('screens.today.smartPlan.psych.procrastination.lowInsight', {'score': procrastScore.toString()}));
    }

    // 认知负荷模式
    if (cogCode == 'burstStall') {
        insights.add(L.get('screens.today.smartPlan.psych.cognitiveInsight.burstStall'));
        recommendations.add(L.get('screens.today.smartPlan.psych.recommendations.minExecutionBaseline'));
    } else if (cogCode == 'stable') {
        insights.add(L.get('screens.today.smartPlan.psych.cognitiveInsight.stable'));
    } else if (cogCode == 'lowStart') {
        insights.add(L.get('screens.today.smartPlan.psych.cognitiveInsight.lowStart'));
        recommendations.add(L.get('screens.today.smartPlan.psych.recommendations.alignWithGoals'));
    } else {
        insights.add(L.get('screens.today.smartPlan.psych.cognitiveInsight.fluctuating'));
    }

    // 自我效能感
    insights.add(selfEfficacy);
    if (continuityRate < 0.5) {
      recommendations.add('「成功螺旋」策略：先处理一件有把握的小任务，用成就感驱动后续执行');
    }

    // 忽略行为分析
    if (ignoreRate > 0.15) {
      final percent = ((ignoreRate * 100).round()).toString();
      insights.add(L.get('screens.today.smartPlan.psych.ignoreRateInsight', {'percent': percent}));
    }

    // 专注深度
    final withFocus = allTasks.where((t) => t.done && t.focusSecs > 60).toList();
    if (withFocus.isNotEmpty) {
      final avgFocusMin = withFocus.fold(0, (s, t) => s + t.focusSecs) / withFocus.length / 60;
      if (avgFocusMin < 10) {
        insights.add(L.get('screens.today.smartPlan.psych.deepFocus.insufficientInsight', {'mins': avgFocusMin.round().toString()}));
        recommendations.add(L.get('screens.today.smartPlan.psych.recommendations.singleTaskFocus'));
      }
    }

    return PsychProfile(
      procrastinationIndex: procrastScore,
      cognitivePattern: cognitivePattern,
      selfEfficacy: selfEfficacy,
      insights: insights,
      recommendations: recommendations,
    );
  }
}

// Helper shared across SmartPlan and PsychAnalyzer
class _SmartUtils {
  static List<String> pastDays(String today, int n) {
    final result = <String>[];
    final d = DateTime.parse('${today}T12:00:00');
    for (int i = n; i >= 1; i--) {
      result.add(AppState.dateKey(d.subtract(Duration(days: i))));
    }
    return result;
  }
}
