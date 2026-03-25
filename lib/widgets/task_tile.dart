// lib/widgets/task_tile.dart
import 'dart:math' show Random, pi, cos, sin;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/crash_logger.dart';
import '../services/pom_engine.dart';
import '../services/focus_quality_service.dart';
import '../l10n/l10n.dart';

// kBlocks 根据当前节日主题动态返回时段标签
// 端午节：🌸晨露 / 🎋午荷 / 🐉暮棹
Map<String, Map<String, dynamic>> kBlocksForTheme(String theme) {
  if (theme == 'dragon_boat') {
    return {
      'morning':   {'name': L.get('time.morning_dragon'), 'emoji': '🌸', 'color': const Color(0xFF2A9C72)},
      'afternoon': {'name': L.get('time.afternoon_dragon'), 'emoji': '🎋', 'color': const Color(0xFF1A7868)},
      'evening':   {'name': L.get('time.evening_dragon'), 'emoji': '🐉', 'color': const Color(0xFF4A7A30)},
    };
  }
  if (theme == 'black_hole') {
    return {
      'morning':   {'name': L.morning, 'emoji': '🚀', 'color': const Color(0xFFA060FF)},
      'afternoon': {'name': L.afternoon, 'emoji': '🛰️', 'color': const Color(0xFF7040B0)},
      'evening':   {'name': L.evening, 'emoji': '🛸', 'color': const Color(0xFF8A80A0)},
    };
  }
  return {
    'morning':   {'name': L.morning,   'emoji': '🌅', 'color': const Color(0xFFe8982a)},
    'afternoon': {'name': L.afternoon, 'emoji': '☀️', 'color': const Color(0xFF3a90c0)},
    'evening':   {'name': L.evening,   'emoji': '🌙', 'color': const Color(0xFF7a5ab8)},
  };
}

Map<String, Map<String, dynamic>> get kBlocks => {
  'morning':   {'name': L.morning,   'emoji': '🌅', 'color': const Color(0xFFe8982a)},
  'afternoon': {'name': L.afternoon, 'emoji': '☀️', 'color': const Color(0xFF3a90c0)},
  'evening':   {'name': L.evening,   'emoji': '🌙', 'color': const Color(0xFF7a5ab8)},
};

class TaskTile extends StatefulWidget {
  final TaskModel task;
  final bool showDate;
  final bool showBlock;
  final bool compact;
  final VoidCallback? onDeleted;
  final VoidCallback? onPlayTap; // if provided, play button calls this instead of inline logic

  const TaskTile({super.key, required this.task, this.showDate = false,
    this.showBlock = false, this.compact = false, this.onDeleted, this.onPlayTap});

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> with SingleTickerProviderStateMixin {
  bool _editing = false;
  late TextEditingController _ctrl;
  late AnimationController _checkCtrl;
  late Animation<double> _checkScale;
  late Animation<double> _checkFade;
  bool _wasDone = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.task.text);
    _wasDone = widget.task.done;
    _checkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _checkScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4)
          .chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0)
          .chain(CurveTween(curve: Curves.elasticOut)), weight: 60),
    ]).animate(_checkCtrl);
    _checkFade = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _checkCtrl, curve: const Interval(0, 0.3)));
  }

  @override
  void dispose() { _ctrl.dispose(); _checkCtrl.dispose(); super.dispose(); }

  @override
  void didUpdateWidget(TaskTile old) {
    super.didUpdateWidget(old);
    if (!_wasDone && widget.task.done) {
      _checkCtrl.forward(from: 0);
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
      // Confetti animation if animations enabled
      final state = context.read<AppState>();
      if (state.settings.theme == 'world_tb_day') {
        _showMicrobeDissipate(context, Color(context.read<AppState>().themeConfig.acc));
      } else if (state.settings.animationsEnhanced) {
        _showConfetti(context, Color(context.read<AppState>().themeConfig.acc));
      }
    }
    _wasDone = widget.task.done;
  }

  void _showConfetti(BuildContext ctx, Color accent) {
    final overlay = Overlay.of(ctx);
    final entry = OverlayEntry(
      builder: (_) => _ConfettiOverlay(accent: accent));
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 1200), entry.remove);
  }

  void _showMicrobeDissipate(BuildContext ctx, Color accent) {
    final overlay = Overlay.of(ctx);
    final entry = OverlayEntry(
      builder: (_) => _MicrobeDissipateOverlay(accent: accent));
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 1500), entry.remove);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final t = widget.task;
    final tc = state.themeConfig;
    final card = Color(tc.card);
    final tx = Color(tc.tx);
    final tm = Color(tc.tm);
    final na = Color(tc.na);
    final nt = Color(tc.nt);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: t.done ? Colors.transparent : card,
        borderRadius: BorderRadius.circular(10),
        boxShadow: t.done ? null : [
          BoxShadow(color: Color(0x0F000000), blurRadius: 5, offset: const Offset(0, 1)),
        ],
      ),
      child: Opacity(
        opacity: t.done ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Animated checkbox ──────────────────────────
              GestureDetector(
                onTap: () {
                  final wasDone = t.done;
                  state.toggleTask(t.id);
                  // When marking DONE (not undone): optionally ask for focus score
                  if (!wasDone && state.settings.focusQualityEnabled) {
                    Future.delayed(const Duration(milliseconds: 350), () {
                      if (context.mounted) {
                        _showTaskQualityRating(context, t, state);
                      }
                    });
                  }
                },
                child: AnimatedBuilder(
                  animation: _checkCtrl,
                  builder: (_, child) => Transform.scale(
                    scale: t.done ? _checkScale.value : 1.0,
                    child: child,
                  ),
                  child: Container(
                    width: 19, height: 19,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: t.done ? null : Border.all(color: tm, width: 1.5),
                      color: t.done ? na : Colors.transparent,
                    ),
                    child: t.done ? Icon(Icons.check, size: 11, color: nt) : null,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              // Content
              Expanded(
                child: _TaskTileContent(
                  task: t,
                  editing: _editing,
                  ctrl: _ctrl,
                  onEditSubmit: (v) {
                    if (v.trim().isNotEmpty) state.editTask(t.id, v.trim());
                    setState(() => _editing = false);
                  },
                  onEditTapOutside: () {
                    if (_ctrl.text.trim().isNotEmpty) state.editTask(t.id, _ctrl.text.trim());
                    setState(() => _editing = false);
                  },
                  onLongPress: () => setState(() => _editing = true),
                  showBlock: widget.showBlock,
                  showDate: widget.showDate,
                  onPlayTap: widget.onPlayTap,
                ),
              ),
              // ── Play/Pause button — three states, large hit area ─────
              if (!t.done)
                _PomTaskBtn(
                  task: t,
                  accentColor: Color(tc.acc),
                  onPlayTap: widget.onPlayTap,
                ),
              // (Delete is via left-swipe on the task tile in today_screen)
            ],
          ),
        ),
      ),
    );
  }



  /// 任务完成后弹出专注质量评分小 sheet
  void _showTaskQualityRating(
      BuildContext ctx, TaskModel task, AppState state) {
    final tc  = state.themeConfig;
    final acc = Color(tc.acc);
    int? selected;

    // Only show if the task actually had focus time recorded
    // (avoids nagging for tasks completed without a pomodoro)
    // We show it regardless so the user can freely rate manual tasks too.
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Color(tc.card),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSt) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Color(tc.brd),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),

            // Task name
            Row(children: [
              Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: task.tags.isNotEmpty
                          ? state.tagColor(task.tags.first)
                          : Color(tc.acc))),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(tc.tx)),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Text('完成这个任务时，你的专注度如何？',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(tc.tx))),
            const SizedBox(height: 14),

            // 5-star rating row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (i) {
                final score = i + 1;
                const emojis = ['😩', '😕', '😐', '😊', '🔥'];
                const labels = ['很差', '较差', '一般', '不错', '极佳'];
                final isSel = selected == score;
                return GestureDetector(
                  onTap: () {
                    setSt(() => selected = score);
                    HapticFeedback.lightImpact();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                        color: isSel
                            ? acc.withOpacity(0.14)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isSel ? acc : Color(tc.brd),
                            width: 1.5)),
                    child: Column(children: [
                      Text(emojis[i],
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(labels[i],
                          style: TextStyle(
                              fontSize: 9.5,
                              color: isSel ? acc : Color(tc.ts),
                              fontWeight: isSel
                                  ? FontWeight.w700
                                  : FontWeight.normal)),
                    ]),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Confirm button
            GestureDetector(
              onTap: () {
                if (selected != null) {
                  // Record a task-completion quality entry
                  final now = DateTime.now();
                  FocusQualityService.addEntry(FocusQualityEntry(
                    date: state.todayKey,
                    hour: now.hour,
                    sessionMins: (task.focusSecs / 60).round(),
                    subjectiveScore: selected,
                    objectiveScore: task.focusSecs > 0 ? 1.0 : 0.8,
                    taskId: task.id.toString(),
                  ));
                }
                Navigator.pop(sheetCtx);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: selected != null ? acc : Color(tc.brd),
                    borderRadius: BorderRadius.circular(14)),
                child: Text(
                    selected != null ? '提交评分' : '跳过',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: selected != null
                            ? Colors.white
                            : Color(tc.tm))),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// Section header widget
class SectionHeader extends StatelessWidget {
  final String block;
  final int pending;
  final int total;
  final bool open;
  final VoidCallback onTap;

  const SectionHeader({super.key, required this.block, required this.pending, required this.total, required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = context.read<AppState>().settings.theme;
    final b = kBlocksForTheme(theme)[block]!;
    final col = b['color'] as Color;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: col)),
            const SizedBox(width: 8),
            Text('${b['emoji']} ${b['name']}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: col)),
            const Spacer(),
            if (pending > 0) Text('$pending 待 ', style: TextStyle(fontSize: 10, color: col, fontWeight: FontWeight.w600)),
            Text('$total 项', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            const SizedBox(width: 6),
            AnimatedRotation(
              turns: open ? 0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Animated play button with spring press ───────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// 三态番茄钟播放按钮：▶ 开始 / ⏸ 暂停 / ▶ 继续
// 大尺寸、居中、不强制跳转 Tab
// ─────────────────────────────────────────────────────────────────────────────
class _TaskTileContent extends StatelessWidget {
  final TaskModel task;
  final bool editing;
  final TextEditingController ctrl;
  final Function(String) onEditSubmit;
  final VoidCallback onEditTapOutside;
  final VoidCallback onLongPress;
  final bool showBlock;
  final bool showDate;
  final VoidCallback? onPlayTap;

  const _TaskTileContent({
    super.key,
    required this.task,
    required this.editing,
    required this.ctrl,
    required this.onEditSubmit,
    required this.onEditTapOutside,
    required this.onLongPress,
    required this.showBlock,
    required this.showDate,
    this.onPlayTap,
  });

  String _fmtTime(int sec) {
    if (sec < 60) return '${sec}秒';
    if (sec < 3600) return '${sec ~/ 60}分';
    return '${sec ~/ 3600}h${sec % 3600 ~/ 60 > 0 ? '${sec % 3600 ~/ 60}m' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.themeConfig;
    final tx = Color(tc.tx);
    final tm = Color(tc.tm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        editing
            ? TextField(
                controller: ctrl,
                autofocus: true,
                style: TextStyle(fontSize: 13.5, color: tx, fontFamily: 'serif'),
                decoration: InputDecoration(
                  border: UnderlineInputBorder(borderSide: BorderSide(color: Color(tc.acc))),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(tc.acc))),
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  fillColor: Colors.transparent,
                  filled: false,
                ),
                onSubmitted: onEditSubmit,
                onTapOutside: (_) => onEditTapOutside(),
              )
            : GestureDetector(
                onLongPress: onLongPress,
                child: Text(
                  task.text,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: task.done ? tm : tx,
                    decoration: task.done ? TextDecoration.lineThrough : null,
                    fontFamily: 'serif',
                  ),
                ),
              ),
        if (task.tags.isNotEmpty) ...[
          const SizedBox(height: 5),
          Wrap(
            spacing: 3,
            runSpacing: 3,
            children: task.tags.map((tag) {
              final c = state.tagColor(tag);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(tag, style: TextStyle(fontSize: 10, color: c)),
              );
            }).toList(),
          ),
        ],
        if (showBlock || showDate || (task.focusSecs > 0 && state.settings.pom.trackTime)) ...[
          const SizedBox(height: 3),
          Wrap(
            spacing: 8,
            children: [
              if (task.focusSecs > 0 && state.settings.pom.trackTime) ...[
                Text('⏱ ${_fmtTime(task.focusSecs)}', style: TextStyle(fontSize: 9.5, color: Color(tc.acc))),
                Builder(builder: (_) {
                  final pomSecs = state.settings.pom.focusMins * 60;
                  final done = task.focusSecs ~/ pomSecs;
                  if (done == 0) return const SizedBox.shrink();
                  return Text('🍅×$done', style: TextStyle(fontSize: 9.5, color: Color(tc.acc)));
                }),
              ],
              if (showBlock) ...[
                Builder(builder: (_) {
                  final blocks = kBlocksForTheme(state.settings.theme);
                  final blk = blocks[task.timeBlock];
                  if (blk == null) return const SizedBox.shrink();
                  return Text('${blk['emoji']} ${blk['name']}', style: TextStyle(fontSize: 9.5, color: blk['color']));
                }),
              ],
              if (showDate)
                Text(task.createdAt, style: TextStyle(fontSize: 9.5, color: Color(tc.ts))),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Animated play button with spring press ───────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// 三态番茄钟播放按钮：▶ 开始 / ⏸ 暂停 / ▶ 继续
// 大尺寸、居中、不强制跳转 Tab
// ─────────────────────────────────────────────────────────────────────────────
class _PomTaskBtn extends StatefulWidget {
  final TaskModel task;
  final Color accentColor;
  final VoidCallback? onPlayTap;
  const _PomTaskBtn({required this.task, required this.accentColor, this.onPlayTap});
  @override State<_PomTaskBtn> createState() => _PomTaskBtnState();
}
class _PomTaskBtnState extends State<_PomTaskBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.84)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeIn));
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }

  void _onTap(BuildContext context) {
    HapticFeedback.mediumImpact();
    final state = context.read<AppState>();
    final engine = state.engine;
    // sameTask: 当前绑定任务 = 本任务（不论 initialized 状态）
    final sameTask = engine.selTaskId == widget.task.id;

    CrashLogger.action('PomTaskBtn',
      'tap taskId=\${widget.task.id} sameTask=\$sameTask running=\${engine.running}');

    if (sameTask && engine.running) {
      // ⏸ 暂停
      state.pomPause();
      // 暂停时不跳转 Tab
    } else if (sameTask && !engine.running) {
      // ▶ 继续（已绑定同一任务，直接 start，不 reset）
      state.pomStart();
      // 继续时跳转到番茄钟
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.onPlayTap != null) {
          widget.onPlayTap!();
        } else {
          AppState.switchToPomodoroTab?.call();
        }
      });
    } else {
      // ▶ 新任务，重置绑定并启动
      state.pomReset();
      state.pomSelectTask(widget.task.id);
      state.pomStart();
      // 新任务开始时跳转到番茄钟
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.onPlayTap != null) {
          widget.onPlayTap!();
        } else {
          AppState.switchToPomodoroTab?.call();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final engine = appState.engine;
    final acc = widget.accentColor;
    final sameTask = engine.selTaskId == widget.task.id;
    final isRunning = sameTask && engine.running;
    // isPaused: same task, not running, but engine was started at least once
    final isPaused  = sameTask && !engine.running && engine.secsLeft < engine.totalSecs;

    // 状态颜色与图标
    final Color bgColor;
    final Color fgColor;
    final IconData icon;
    final String label;

    if (isRunning) {
      bgColor = acc;
      fgColor = Colors.white;
      icon    = Icons.pause_rounded;
      label   = '暂停';
    } else if (isPaused) {
      bgColor = acc.withOpacity(0.15);
      fgColor = acc;
      icon    = Icons.play_arrow_rounded;
      label   = '继续';
    } else {
      bgColor = acc.withOpacity(0.09);
      fgColor = acc.withOpacity(0.80);
      icon    = Icons.play_arrow_rounded;
      label   = '';
    }

    final progress = (isRunning || isPaused) && engine.totalSecs > 0
        ? engine.secsLeft / engine.totalSecs
        : 0.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ac.forward(),
      onTapCancel: () => _ac.reverse(),
      onTapUp: (_) {
        _ac.reverse();
        _onTap(context);
      },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Stack(alignment: Alignment.center, children: [
              if (isRunning || isPaused)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CustomPaint(
                    painter: _MiniArcPainter(
                      progress: progress,
                      color: acc.withOpacity(0.2),
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              Icon(icon, size: 20, color: fgColor),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MicrobeDissipateOverlay extends StatefulWidget {
  final Color accent;
  const _MicrobeDissipateOverlay({required this.accent});

  @override
  _MicrobeDissipateOverlayState createState() => _MicrobeDissipateOverlayState();
}

class _MicrobeDissipateOverlayState extends State<_MicrobeDissipateOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MicrobeDissipatePainter(
        animation: _controller,
        color: widget.accent,
      ),
      size: Size.infinite,
    );
  }
}

class _MicrobeDissipatePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  final _random = Random(10);
  final List<_MicrobeParticle> _particles = [];

  _MicrobeDissipatePainter({required this.animation, required this.color})
      : super(repaint: animation) {
    if (_particles.isEmpty) {
      for (int i = 0; i < 50; i++) {
        final t = _random.nextDouble();
        final double x = (t - 0.5) * 30;
        final double y = (_random.nextDouble() - 0.5) * 6;
        _particles.add(_MicrobeParticle(
          x: x,
          y: y,
          vx: (_random.nextDouble() - 0.5) * 2.5,
          vy: (_random.nextDouble() - 0.5) * 2.5 - 1.5,
          startSize: _random.nextDouble() * 2.0 + 1.0,
        ));
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final progress = animation.value;

    canvas.translate(size.width / 2, size.height / 2);

    if (progress < 0.3) {
      final rodPaint = Paint()
        ..color = color.withOpacity(1.0 - (progress / 0.3));
      final RRect rod =
          RRect.fromLTRBR(-15, -3, 15, 3, const Radius.circular(3));
      canvas.drawRRect(rod, rodPaint);
    } else {
      final particleProgress = (progress - 0.3) / 0.7;
      for (final p in _particles) {
        final currentX = p.x + p.vx * particleProgress * 20;
        final currentY =
            p.y + (p.vy - particleProgress * 3.0) * particleProgress * 20;
        final currentSize = p.startSize * (1 - particleProgress);
        if (currentSize > 0) {
          paint.color = color
              .withOpacity((1 - particleProgress).clamp(0.0, 1.0));
          canvas.drawCircle(Offset(currentX, currentY), currentSize, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_MicrobeDissipatePainter oldDelegate) => false;
}

class _MicrobeParticle {
  double x, y, vx, vy, startSize;
  _MicrobeParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.startSize,
  });
}

class _MiniArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _MiniArcPainter({required this.progress, required this.color, this.strokeWidth = 3});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, paint);
  }

  @override
  bool shouldRepaint(_MiniArcPainter old) =>
      progress != old.progress || color != old.color;
}

// ── 任务完成彩带粒子覆盖层 ────────────────────────────────────────────────────
class _ConfettiOverlay extends StatefulWidget {
  final Color accent;
  const _ConfettiOverlay({required this.accent});
  @override State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Particle> _particles;
  static final _rng = Random();

  @override
  void initState() {
    super.initState();
    _particles = List.generate(22, (_) => _Particle(widget.accent, _rng));
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1100))..forward();
    _ctrl.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned(
      left: 0, top: size.height * 0.3, right: 0, height: size.height * 0.45,
      child: IgnorePointer(
        child: CustomPaint(
          painter: _ConfettiPainter(_particles, _ctrl.value))));
  }
}

class _Particle {
  final double x, vx, vy, size, rotation, rotSpeed;
  final Color color;
  _Particle(Color accent, Random rng)
      : x = rng.nextDouble(),
        vx = (rng.nextDouble() - 0.5) * 0.4,
        vy = 0.3 + rng.nextDouble() * 0.7,
        size = 5 + rng.nextDouble() * 8,
        rotation = rng.nextDouble() * 2 * pi,
        rotSpeed = (rng.nextDouble() - 0.5) * 8,
        color = _pickColor(accent, rng);

  static Color _pickColor(Color acc, Random r) {
    final palette = [acc, acc.withOpacity(0.7),
      const Color(0xFFFFD700), const Color(0xFFFF6B6B),
      const Color(0xFF6BCB77), const Color(0xFF4D96FF)];
    return palette[r.nextInt(palette.length)];
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t; // 0→1
  const _ConfettiPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final px = (p.x + p.vx * t) * size.width;
      final py = p.vy * t * size.height;
      final alpha = t < 0.7 ? 1.0 : (1.0 - t) / 0.3;
      final paint = Paint()
        ..color = p.color.withOpacity(alpha.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation + p.rotSpeed * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero,
              width: p.size, height: p.size * 0.5),
          const Radius.circular(2)),
        paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter o) => o.t != t;
}
