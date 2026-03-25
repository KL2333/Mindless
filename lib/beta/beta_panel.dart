// lib/beta/beta_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import 'beta_flags.dart';
import 'usage_stats_service.dart';
import 'smart_plan.dart';
import 'task_gravity.dart';

/// Displayed at the bottom of TodayScreen when kBetaFeatures = true.
class BetaTodayPanel extends StatefulWidget {
  const BetaTodayPanel({super.key});
  @override
  State<BetaTodayPanel> createState() => _BetaTodayPanelState();
}

class _BetaTodayPanelState extends State<BetaTodayPanel> {
  UsageSummary? _usage;
  bool _hasPermission = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    if (!mounted) return;
    setState(() => _loading = true);
    _hasPermission = await UsageStatsService.hasPermission();
    if (_hasPermission && mounted) {
      final state = context.read<AppState>();
      _usage = await UsageStatsService.getTodayUsage(
        userCategories: state.settings.userAppCategories,
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!kFeatureUsageStats && !kFeatureSmartPlan) return const SizedBox.shrink();
    final state = context.watch<AppState>();
    final tc = state.themeConfig;

    return Column(children: [
      if (betaSmartPlan(state.settings)) _buildSmartPlan(state, tc),
      if (betaUsageStats(state.settings)) _buildUsagePanel(state, tc),
    ]);
  }

  Widget _buildSmartPlan(AppState state, ThemeConfig tc) {
    final suggestion = SmartPlan.suggest(state, usage: _usage);
    final estFocus = SmartPlan.estimateFocusNeeded(state);

    final crossInsights = suggestion.insights
        .where((i) => i.source == InsightSource.crossScreen).toList();
    final taskInsights = suggestion.insights
        .where((i) => i.source == InsightSource.task ||
                      i.source == InsightSource.crossTask ||
                      i.source == InsightSource.trend).toList();
    final screenInsights = suggestion.insights
        .where((i) => i.source == InsightSource.screen).toList();

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: BoxDecoration(
        color: Color(tc.card),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Color(0x0E000000), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ══ 顶栏：HPI 仪表 + 标题 ══════════════════════════════════════
        _SmartHeader(suggestion: suggestion, estFocus: estFocus, tc: tc,
            hasCrossData: _usage != null),

        // ══ 总结一句话 ═══════════════════════════════════════════════════
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Text(suggestion.summary,
            style: TextStyle(fontSize: 11.5, color: Color(tc.ts), height: 1.55))),

        // ══ 警告条（任务量过多/过少）════════════════════════════════════
        if (suggestion.loadWarning.isNotEmpty)
          _WarningBar(text: suggestion.loadWarning, tc: tc),

        // ══ 任务分配建议卡片列 ════════════════════════════════════════════
        if (suggestion.moves.isNotEmpty) ...[
          _SectionDivider(label: '分配建议', tc: tc),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Column(children: [
              ...suggestion.moves.take(4).map((m) => _MoveCard(
                  move: m, state: state, tc: tc)),
              const SizedBox(height: 8),
              _ApplyMovesButton(suggestion: suggestion, state: state, tc: tc),
            ])),
        ],

        // ══ 屏幕 × 任务 交叉洞察 ════════════════════════════════════════
        if (crossInsights.isNotEmpty) ...[
          _SectionDivider(label: '跨维度分析', tc: tc,
              accent: const Color(0xFF5060D0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Column(children: crossInsights.take(3)
                .map((ins) => _InsightCard(ins: ins, tc: tc, cross: true))
                .toList())),
        ],

        // ══ 任务效率洞察 ═════════════════════════════════════════════════
        if (taskInsights.isNotEmpty) ...[
          _SectionDivider(label: '任务效率', tc: tc),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Column(children: taskInsights.take(5)
                .map((ins) => _InsightCard(ins: ins, tc: tc))
                .toList())),
        ],

        // ══ 屏幕效率概览 ═════════════════════════════════════════════════
        if (suggestion.screenSummary != null) ...[
          _SectionDivider(label: '屏幕使用', tc: tc,
              accent: const Color(0xFF3A90C0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: _ScreenEffCard(
              summary: suggestion.screenSummary!,
              score: suggestion.screenEffScore, tc: tc)),
        ],

        // ══ 屏幕洞察 ═════════════════════════════════════════════════════
        if (screenInsights.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Column(children: screenInsights.take(3)
                .map((ins) => _InsightCard(ins: ins, tc: tc))
                .toList())),

        const SizedBox(height: 4),
      ]),
    );
  }


  Widget _buildInsightRow(Insight ins, ThemeConfig tc, {bool compact = false}) {
    final confColor = ins.confidence == Confidence.high
        ? const Color(0xFF4A9068)
        : ins.confidence == Confidence.medium
            ? const Color(0xFFDAA520)
            : Color(tc.tm);
    // Source accent for crossScreen insights
    final isCross = ins.source == InsightSource.crossScreen;
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 5 : 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ins.icon, style: TextStyle(fontSize: compact ? 12 : 14)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Expanded(child: Text(ins.title,
              style: TextStyle(
                fontSize: compact ? 10.5 : 11,
                color: isCross ? const Color(0xFF5060D0) : Color(tc.tx),
                fontWeight: FontWeight.w600))),
            Container(width: 6, height: 6,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: confColor)),
          ]),
          const SizedBox(height: 2),
          Text(ins.body, style: TextStyle(
            fontSize: compact ? 9.5 : 10,
            color: Color(tc.ts), height: 1.4)),
        ])),
      ]),
    );
  }

  Widget _buildUsagePanel(AppState state, ThemeConfig tc) {
    if (_loading) return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(tc.acc))));

    if (!_hasPermission) {
      return Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Color(tc.card), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('β 屏幕使用分析', style: TextStyle(fontSize: 9.5, color: Color(tc.acc))),
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: Color(tc.acc).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text('BETA', style: TextStyle(fontSize: 7, color: Color(tc.acc), fontWeight: FontWeight.w700, letterSpacing: 1))),
            ]),
            const SizedBox(height: 4),
            Text('需要"使用情况访问"权限', style: TextStyle(fontSize: 11, color: Color(tc.ts))),
          ])),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () async {
              await UsageStatsService.requestPermission();
              await Future.delayed(const Duration(seconds: 2));
              _loadUsage();
            },
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: Color(tc.na), borderRadius: BorderRadius.circular(10)),
              child: Text('授权', style: TextStyle(fontSize: 12, color: Color(tc.nt)))),
          ),
        ]),
      );
    }

    if (_usage == null) return const SizedBox.shrink();

    final u = _usage!;
    final focusSecs = state.todayFocusSecs();
    final effScore = u.efficiencyScore(focusSecs);
    final effColor = effScore >= 70 ? const Color(0xFF4A9068)
        : effScore >= 40 ? const Color(0xFFDAA520) : const Color(0xFFE07040);

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Color(tc.card), borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('β 屏幕使用分析', style: TextStyle(fontSize: 9.5, letterSpacing: 1.2, color: Color(tc.acc))),
          const SizedBox(width: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: Color(tc.acc).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Text('BETA', style: TextStyle(fontSize: 7, color: Color(tc.acc), fontWeight: FontWeight.w700, letterSpacing: 1))),
          const Spacer(),
          GestureDetector(onTap: _loadUsage, child: Icon(Icons.refresh, size: 14, color: Color(tc.tm))),
        ]),
        const SizedBox(height: 12),
        // Efficiency score
        Row(children: [
          Text('今日效率评分', style: TextStyle(fontSize: 11, color: Color(tc.ts))),
          const Spacer(),
          Text('$effScore', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: effColor)),
          Text('/100', style: TextStyle(fontSize: 12, color: Color(tc.tm))),
        ]),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(value: effScore / 100, backgroundColor: Color(tc.brd),
            color: effColor, minHeight: 4)),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.merge_type_rounded, size: 11, color: Color(tc.acc).withOpacity(0.7)),
          const SizedBox(width: 4),
          Text('屏幕数据已同步至智能建议分析',
            style: TextStyle(fontSize: 9.5, color: Color(tc.acc).withOpacity(0.7),
              fontStyle: FontStyle.italic)),
        ]),
        const SizedBox(height: 8),
        // Category chips
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (u.totalSocialMs > 0)   _usageChip('📱 社交',   u.totalSocialMs,   const Color(0xFFE07040)),
          if (u.totalVideoMs > 0)    _usageChip('🎬 视频',   u.totalVideoMs,    const Color(0xFF5060D0)),
          if (u.totalGameMs > 0)     _usageChip('🎮 游戏',   u.totalGameMs,     const Color(0xFF4A9068)),
          if (u.totalMusicMs > 0)    _usageChip('🎵 音乐',   u.totalMusicMs,    const Color(0xFFD070C0)),
          if (u.totalNewsMs > 0)     _usageChip('📰 资讯',   u.totalNewsMs,     const Color(0xFF3A90C0)),
          if (u.totalShoppingMs > 0) _usageChip('🛒 购物',   u.totalShoppingMs, const Color(0xFFE0A030)),
          if (u.totalCustomMs > 0)   _usageChip('⭐ 自定义', u.totalCustomMs,   const Color(0xFFE0A040)),
        ]),
        if (u.totalEntertainMs > 0) ...[
          const SizedBox(height: 8),
          Text(
            '娱乐合计 ${u.entertainMinutes}分钟 · ${_entertainComment(u.totalEntertainMs, focusSecs)}',
            style: TextStyle(fontSize: 10, color: Color(tc.tm))),
        ],
        // Top entertainment apps only
        if (u.apps.where((a) => a.type != 'other').isNotEmpty) ...[
          Divider(height: 16, color: Color(tc.brd)),
          ...u.apps.where((a) => a.type != 'other').take(5).map((a) =>
            Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle,
                color: _typeColor(a.type, tc))),
              const SizedBox(width: 6),
              Expanded(child: Text(a.appName, style: TextStyle(fontSize: 11, color: Color(tc.tx)))),
              Text(a.minutes, style: TextStyle(fontSize: 11, color: Color(tc.ts), fontWeight: FontWeight.w600)),
            ]))),
        ],
      ]),
    );
  }

  Color _typeColor(String type, ThemeConfig tc) {
    switch (type) {
      case 'social':   return const Color(0xFFE07040);
      case 'video':    return const Color(0xFF5060D0);
      case 'game':     return const Color(0xFF4A9068);
      case 'music':    return const Color(0xFFD070C0);
      case 'news':     return const Color(0xFF3A90C0);
      case 'shopping': return const Color(0xFFE0A030);
      case 'custom':   return const Color(0xFFE0A040);
      case 'work':     return const Color(0xFF607080);
      default:         return Color(tc.tm);
    }
  }

  Widget _usageChip(String label, int ms, Color c) {
    final mins = (ms / 60000).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.withOpacity(0.09), borderRadius: BorderRadius.circular(8)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 9.5, color: c)),
        const SizedBox(height: 2),
        Text('${mins}m', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c)),
      ]),
    );
  }

  String _entertainComment(int entertainMs, int focusSecs) {
    final eH = entertainMs / 3600000;
    final fH = focusSecs / 3600;
    if (fH == 0) return '今天还没有专注记录';
    if (eH < fH * 0.5) return '娱乐适度，效率良好 ✓';
    if (eH < fH) return '娱乐接近专注时长，注意节制';
    return '娱乐超过专注时长，建议调整';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Full-page app category picker — lists all installed apps, lets user assign
/// each to social / video / game / custom / work / other.
class AppCategoryPage extends StatefulWidget {
  final ThemeConfig tc;
  const AppCategoryPage({super.key, required this.tc});
  @override
  State<AppCategoryPage> createState() => _AppCategoryPageState();
}

class _AppCategoryPageState extends State<AppCategoryPage> {
  List<InstalledApp> _apps = [];
  bool _loading = true;
  String _search = '';

  static const _categories = [
    ('social',   '📱 社交',   Color(0xFFE07040)),
    ('video',    '🎬 视频',   Color(0xFF5060D0)),
    ('game',     '🎮 游戏',   Color(0xFF4A9068)),
    ('music',    '🎵 音乐',   Color(0xFFD070C0)),
    ('news',     '📰 资讯',   Color(0xFF3A90C0)),
    ('shopping', '🛒 购物',   Color(0xFFE0A030)),
    ('custom',   '⭐ 自定义', Color(0xFFE0A040)),
    ('work',     '💼 工作',   Color(0xFF607080)),
    ('other',    '○ 其他',   Color(0xFF888888)),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final apps = await UsageStatsService.getInstalledApps();
    if (mounted) setState(() { _apps = apps; _loading = false; });
  }

  String _effectiveCategory(AppState state, InstalledApp app) =>
      state.settings.userAppCategories[app.package] ?? app.defaultCategory;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = widget.tc;
    final filtered = _search.isEmpty
        ? _apps
        : _apps.where((a) =>
            a.label.toLowerCase().contains(_search.toLowerCase()) ||
            a.package.toLowerCase().contains(_search.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: Color(tc.bg),
      appBar: AppBar(
        backgroundColor: Color(tc.bg), elevation: 0,
        title: Text('应用分类', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(tc.tx))),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 18, color: Color(tc.ts)),
          onPressed: () => Navigator.pop(context)),
        actions: [
          // 复制全部包名（供 AI 分析）
          Consumer<AppState>(
            builder: (_, st, __) => TextButton.icon(
              onPressed: _apps.isEmpty ? null : () {
                final buf = StringBuffer();
                buf.writeln('# 已安装 App 包名列表（共 ${_apps.length} 个）');
                buf.writeln('# 格式：包名 | 当前分类');
                buf.writeln();
                for (final app in _apps) {
                  final cat = _effectiveCategory(st, app);
                  buf.writeln('${app.package} | $cat');
                }
                Clipboard.setData(ClipboardData(text: buf.toString()));
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('已复制全部 ${_apps.length} 个包名',
                    style: const TextStyle(fontSize: 12)),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ));
              },
              icon: Icon(Icons.copy_all_rounded, size: 14, color: Color(tc.acc)),
              label: Text('复制全部', style: TextStyle(fontSize: 12, color: Color(tc.acc))),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
          ),
          // Reset all
          TextButton(
            onPressed: () {
              showDialog(context: context, builder: (_) => AlertDialog(
                backgroundColor: Color(tc.card),
                title: Text('重置所有分类', style: TextStyle(color: Color(tc.tx))),
                content: Text('将清除所有自定义分类，恢复默认。', style: TextStyle(color: Color(tc.ts))),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context),
                    child: Text('取消', style: TextStyle(color: Color(tc.ts)))),
                  TextButton(onPressed: () {
                    state.resetAppCategories();
                    Navigator.pop(context);
                  }, child: const Text('重置', style: TextStyle(color: Color(0xFFE04040)))),
                ],
              ));
            },
            child: Text('重置', style: TextStyle(fontSize: 13, color: Color(tc.ts))),
          ),
        ],
      ),
      body: Column(children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: TextStyle(fontSize: 13, color: Color(tc.tx)),
            decoration: InputDecoration(
              hintText: '搜索应用名称或包名…',
              hintStyle: TextStyle(color: Color(tc.tm), fontSize: 12),
              prefixIcon: Icon(Icons.search, size: 18, color: Color(tc.tm)),
              fillColor: Color(tc.card),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
          ),
        ),
        // Category legend
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(spacing: 6, runSpacing: 4,
            children: _categories.map((c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: c.$3.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8)),
              child: Text('${c.$2}', style: TextStyle(fontSize: 10, color: c.$3)),
            )).toList()),
        ),
        Divider(color: Color(tc.brd), height: 1),
        if (_loading)
          Expanded(child: Center(child: CircularProgressIndicator(color: Color(tc.acc))))
        else
          Expanded(child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final app = filtered[i];
              final current = _effectiveCategory(state, app);
              final catInfo = _categories.firstWhere(
                (c) => c.$1 == current,
                orElse: () => _categories.last);
              final isUserOverride = state.settings.userAppCategories.containsKey(app.package);

              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                title: Row(children: [
                  Expanded(child: Text(app.label,
                    style: TextStyle(fontSize: 13, color: Color(tc.tx)),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (isUserOverride)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.edit_rounded, size: 10, color: Color(tc.acc))),
                ]),
                subtitle: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: app.package));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('已复制：${app.package}',
                        style: const TextStyle(fontSize: 12)),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ));
                  },
                  child: Row(children: [
                    Expanded(child: Text(app.package,
                      style: TextStyle(fontSize: 9.5, color: Color(tc.tm)),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Icon(Icons.copy_rounded, size: 10, color: Color(tc.tm)),
                  ]),
                ),
                trailing: GestureDetector(
                  onTap: () => _showCategoryPicker(context, state, tc, app, current),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: catInfo.$3.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: catInfo.$3.withOpacity(0.35)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(catInfo.$2,
                        style: TextStyle(fontSize: 11, color: catInfo.$3)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, size: 14, color: catInfo.$3),
                    ]),
                  ),
                ),
              );
            },
          )),
      ]),
    );
  }

  void _showCategoryPicker(BuildContext context, AppState state,
      ThemeConfig tc, InstalledApp app, String current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(tc.card),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(app.label,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(tc.tx))),
            Text(app.package,
              style: TextStyle(fontSize: 10, color: Color(tc.tm))),
            const SizedBox(height: 16),
            ..._categories.map((c) {
              final isSelected = current == c.$1;
              return ListTile(
                dense: true,
                leading: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: c.$3.withOpacity(0.12), shape: BoxShape.circle),
                  child: Center(child: Text(c.$2.split(' ').first,
                    style: const TextStyle(fontSize: 16)))),
                title: Text(c.$2.split(' ').last,
                  style: TextStyle(fontSize: 13,
                    color: isSelected ? c.$3 : Color(tc.tx),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal)),
                trailing: isSelected
                    ? Icon(Icons.check_rounded, color: c.$3)
                    : null,
                onTap: () {
                  state.setAppCategory(app.package, c.$1 == app.defaultCategory ? null : c.$1);
                  setState(() {}); // rebuild list
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

// ─── 一键分配按钮 ─────────────────────────────────────────────────────────────
class _ApplyMovesButton extends StatefulWidget {
  final DaySuggestion suggestion;
  final AppState state;
  final ThemeConfig tc;
  const _ApplyMovesButton({required this.suggestion, required this.state, required this.tc});
  @override
  State<_ApplyMovesButton> createState() => _ApplyMovesButtonState();
}

class _ApplyMovesButtonState extends State<_ApplyMovesButton> {
  bool _applied = false;

  void _apply() {
    int count = 0;
    for (final move in widget.suggestion.moves) {
      final id = int.tryParse(move.taskId);
      if (id == null) continue;
      final task = widget.state.tasks.where((t) => t.id == id).firstOrNull;
      if (task == null) continue;
      if (task.timeBlock == 'unassigned' || task.timeBlock == '') {
        widget.state.setTaskTimeBlock(id, move.suggestedBlock);
        count++;
      }
    }
    HapticFeedback.mediumImpact();
    setState(() => _applied = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(count > 0
          ? '已为 $count 件待办分配时段 ✓'
          : '所有待办已有时段，无需分配',
        style: const TextStyle(fontSize: 12)),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.tc;
    final pendingMoves = widget.suggestion.moves.where((m) {
      final id = int.tryParse(m.taskId);
      if (id == null) return false;
      final task = widget.state.tasks.where((t) => t.id == id).firstOrNull;
      return task != null && (task.timeBlock == 'unassigned' || task.timeBlock == '');
    }).length;

    return GestureDetector(
      onTap: (_applied || pendingMoves == 0) ? null : _apply,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: (_applied || pendingMoves == 0)
              ? Color(tc.brd)
              : Color(tc.na),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            _applied || pendingMoves == 0
                ? Icons.check_rounded
                : Icons.auto_fix_high_rounded,
            size: 15,
            color: (_applied || pendingMoves == 0) ? Color(tc.tm) : Color(tc.nt),
          ),
          const SizedBox(width: 6),
          Text(
            _applied
                ? '已按建议分配'
                : pendingMoves == 0
                    ? '无待分配任务'
                    : '一键分配 $pendingMoves 件待办',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: (_applied || pendingMoves == 0) ? Color(tc.tm) : Color(tc.nt),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Task list with gravity-sorted display (β only).
class GravitySortedTaskList extends StatelessWidget {
  final List<TaskModel> tasks;
  final Widget Function(TaskModel) itemBuilder;
  const GravitySortedTaskList({super.key, required this.tasks, required this.itemBuilder});

  @override
  Widget build(BuildContext context) {
    if (!kFeatureTaskGravity) {
      return Column(children: tasks.map(itemBuilder).toList());
    }
    final state = context.read<AppState>();
    final sorted = TaskGravity.sort(List.from(tasks), state);
    return Column(children: sorted.map((t) {
      return Stack(clipBehavior: Clip.none, children: [
        itemBuilder(t),
        Builder(builder: (_) {
          final g = TaskGravity.score(t, state);
          if (g < 3) return const SizedBox.shrink();
          return Positioned(
            top: 4, right: 4,
            child: Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: g < 7 ? const Color(0xFFDAA520) : const Color(0xFFE04040),
              ),
            ),
          );
        }),
      ]);
    }).toList());
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 智能建议重构美术 — 子组件
// ═════════════════════════════════════════════════════════════════════════════

// ── HPI 仪表盘顶栏 ─────────────────────────────────────────────────────────
class _SmartHeader extends StatelessWidget {
  final DaySuggestion suggestion;
  final String estFocus;
  final ThemeConfig tc;
  final bool hasCrossData;
  const _SmartHeader({required this.suggestion, required this.estFocus,
      required this.tc, required this.hasCrossData});

  @override
  Widget build(BuildContext context) {
    final hpi = suggestion.hpi;
    final hpiColor = hpi == null ? const Color(0xFF888888)
        : hpi >= 80 ? const Color(0xFF4A9068)
        : hpi >= 65 ? const Color(0xFF3A90C0)
        : hpi >= 45 ? const Color(0xFFDAA520)
        : const Color(0xFFE07040);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            hpiColor.withOpacity(0.06),
            Colors.transparent,
          ]),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // 左：标题 + 数据来源标签 + 预估专注
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('智能建议', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: Color(tc.tx), letterSpacing: 0.3)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hasCrossData
                    ? const Color(0xFF5060D0).withOpacity(0.12)
                    : Color(tc.acc).withOpacity(0.10),
                borderRadius: BorderRadius.circular(6)),
              child: Text(hasCrossData ? '任务+屏幕' : '任务',
                style: TextStyle(fontSize: 8.5,
                  color: hasCrossData
                      ? const Color(0xFF5060D0) : Color(tc.acc),
                  fontWeight: FontWeight.w700, letterSpacing: 0.5))),
          ]),
          const SizedBox(height: 6),
          // 专注预估 — 小 chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Color(tc.cb),
              borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.timer_outlined, size: 12, color: Color(tc.ts)),
              const SizedBox(width: 4),
              Text(estFocus, style: TextStyle(
                fontSize: 10.5, color: Color(tc.ts))),
            ])),
          if (suggestion.hpiLabel != null) ...[
            const SizedBox(height: 4),
            Text(suggestion.hpiLabel!, style: TextStyle(
              fontSize: 9.5, color: hpiColor.withOpacity(0.85))),
          ],
        ])),

        // 右：HPI 仪表
        if (hpi != null) ...[
          const SizedBox(width: 12),
          _HpiGauge(hpi: hpi, color: hpiColor, tc: tc),
        ],
      ]),
    );
  }
}

// ── HPI 圆形仪表 ───────────────────────────────────────────────────────────
class _HpiGauge extends StatelessWidget {
  final int hpi;
  final Color color;
  final ThemeConfig tc;
  const _HpiGauge({required this.hpi, required this.color, required this.tc});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 64, height: 64,
      child: CustomPaint(
        painter: _GaugePainter(value: hpi / 100.0, color: color,
            bgColor: Color(tc.brd)),
        child: Center(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
          Text('$hpi', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w900, color: color,
            height: 1.0)),
          Text('HPI', style: TextStyle(
            fontSize: 7.5, color: Color(tc.tm),
            letterSpacing: 1.0, fontWeight: FontWeight.w600)),
        ])),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color, bgColor;
  const _GaugePainter({required this.value, required this.color,
      required this.bgColor});
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    const startAngle = 3.14159 * 0.75;  // 135°
    const sweepFull  = 3.14159 * 1.5;   // 270°

    final bg = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r),
        startAngle, sweepFull, false, bg);

    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r),
        startAngle, sweepFull * value.clamp(0.0, 1.0), false, fg);
  }
  @override bool shouldRepaint(_GaugePainter o) => o.value != value;
}

// ── 分区 divider ────────────────────────────────────────────────────────────
class _SectionDivider extends StatelessWidget {
  final String label;
  final ThemeConfig tc;
  final Color? accent;
  const _SectionDivider({required this.label, required this.tc, this.accent});
  @override
  Widget build(BuildContext context) {
    final c = accent ?? Color(tc.ts);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Row(children: [
        Container(width: 3, height: 12,
          decoration: BoxDecoration(
            color: c.withOpacity(0.7),
            borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(
          fontSize: 9.5, fontWeight: FontWeight.w700,
          color: c.withOpacity(0.85), letterSpacing: 0.8)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1,
          color: c.withOpacity(0.12))),
      ]),
    );
  }
}

// ── 警告横条 ────────────────────────────────────────────────────────────────
class _WarningBar extends StatelessWidget {
  final String text;
  final ThemeConfig tc;
  const _WarningBar({required this.text, required this.tc});
  @override
  Widget build(BuildContext context) {
    final isWarn = text.startsWith('⚠');
    final color = isWarn ? const Color(0xFFE07040) : const Color(0xFF4A9068);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Icon(isWarn ? Icons.warning_amber_rounded : Icons.check_circle_outline,
          size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(
          fontSize: 11, color: color, height: 1.4))),
      ]),
    );
  }
}

// ── 分配建议卡 ──────────────────────────────────────────────────────────────
class _MoveCard extends StatelessWidget {
  final BlockSuggestion move;
  final AppState state;
  final ThemeConfig tc;
  const _MoveCard({required this.move, required this.state, required this.tc});

  static const _blkIcon  = {'morning': '🌅', 'afternoon': '☀️', 'evening': '🌙'};
  static const _blkLabel = {'morning': '上午', 'afternoon': '下午', 'evening': '晚上'};

  @override
  Widget build(BuildContext context) {
    final id   = int.tryParse(move.taskId);
    final task = id != null
        ? state.tasks.where((t) => t.id == id).firstOrNull
        : null;
    if (task == null) return const SizedBox.shrink();

    final blk   = move.suggestedBlock;
    final emoji = _blkIcon[blk] ?? '📌';
    final label = _blkLabel[blk] ?? blk;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Color(tc.cb),
        borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        // 时段标签
        Container(
          width: 44,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Color(tc.card),
            borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            Text(label, style: TextStyle(fontSize: 8.5,
              color: Color(tc.ts), fontWeight: FontWeight.w600)),
          ])),
        const SizedBox(width: 10),
        // 任务名 + 理由
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            task.text.length > 20 ? '${task.text.substring(0, 20)}…' : task.text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: Color(tc.tx)),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(move.reason,
            style: TextStyle(fontSize: 10, color: Color(tc.ts), height: 1.3),
            maxLines: 2),
        ])),
      ]),
    );
  }
}

// ── 洞察卡片 ────────────────────────────────────────────────────────────────
class _InsightCard extends StatelessWidget {
  final Insight ins;
  final ThemeConfig tc;
  final bool cross;
  const _InsightCard({required this.ins, required this.tc, this.cross = false});

  @override
  Widget build(BuildContext context) {
    final confColor = ins.confidence == Confidence.high
        ? const Color(0xFF4A9068)
        : ins.confidence == Confidence.medium
            ? const Color(0xFFDAA520)
            : Color(tc.tm);
    final accent = cross ? const Color(0xFF5060D0) : confColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(tc.cb),
        borderRadius: BorderRadius.circular(12),
        border: cross
            ? Border.all(color: const Color(0xFF5060D0).withOpacity(0.20))
            : null),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 图标圆圈
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withOpacity(0.10)),
          child: Center(child: Text(ins.icon,
              style: const TextStyle(fontSize: 15)))),
        const SizedBox(width: 10),
        // 文字内容
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: Text(ins.title,
              style: TextStyle(fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: cross ? const Color(0xFF5060D0) : Color(tc.tx)))),
            // 置信度小点
            Container(width: 7, height: 7,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: confColor.withOpacity(0.8))),
          ]),
          const SizedBox(height: 4),
          Text(ins.body, style: TextStyle(
            fontSize: 10.5, color: Color(tc.ts), height: 1.45)),
        ])),
      ]),
    );
  }
}

// ── 屏幕效率卡 ──────────────────────────────────────────────────────────────
class _ScreenEffCard extends StatelessWidget {
  final String summary;
  final int? score;
  final ThemeConfig tc;
  const _ScreenEffCard({required this.summary, required this.score,
      required this.tc});
  @override
  Widget build(BuildContext context) {
    final sc = score;
    final color = sc == null ? Color(tc.ts)
        : sc >= 70 ? const Color(0xFF4A9068)
        : sc >= 40 ? const Color(0xFFDAA520)
        : const Color(0xFFE07040);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15))),
      child: Row(children: [
        Expanded(child: Text(summary,
          style: TextStyle(fontSize: 11, color: Color(tc.ts), height: 1.4))),
        if (sc != null) ...[
          const SizedBox(width: 12),
          Column(children: [
            Text('$sc', style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900,
              color: color, height: 1.0)),
            Text('效率分', style: TextStyle(
              fontSize: 8.5, color: Color(tc.tm))),
          ]),
        ],
      ]),
    );
  }
}
