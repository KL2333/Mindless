// lib/beta/usage_stats_service.dart
import 'package:flutter/services.dart';

// System/launcher packages to always exclude from display
const _kSystemPkgs = {
  'android', 'com.android.systemui', 'com.android.settings',
  'com.android.launcher', 'com.android.launcher3',
  'com.google.android.apps.nexuslauncher', 'com.miui.home',
  'com.huawei.android.launcher', 'com.oppo.launcher',
  'com.bbk.launcher2', 'com.vivo.launcher',
  'com.coloros.launcher', 'com.oneplus.launcher', 'com.realme.launcher',
  'com.android.inputmethod.latin', 'com.google.android.inputmethod.latin',
  'com.baidu.input', 'com.sogou.android.zhixin',
  'com.android.phone', 'com.android.dialer',
};

// 应用类别定义（供 UI 显示用）
const kAppCategories = [
  ('social',   '📱 社交',   Color(0xFFE07040)),
  ('video',    '🎬 视频',   Color(0xFF5060D0)),
  ('game',     '🎮 游戏',   Color(0xFF4A9068)),
  ('music',    '🎵 音乐',   Color(0xFFD070C0)),
  ('news',     '📰 资讯',   Color(0xFF3A90C0)),
  ('shopping', '🛒 购物',   Color(0xFFE0A030)),
  ('tool',     '🔧 工具',   Color(0xFF808080)),
  ('work',     '💼 工作',   Color(0xFF3A90C0)),
  ('custom',   '⭐ 自定义', Color(0xFFE0A040)),
  ('other',    '○ 其他',   Color(0xFF999999)),
];

// 扩充的内置显示名映射
const _kNames = {
  // 即时通讯 / 社交
  'com.tencent.mm':              '微信',
  'com.tencent.mobileqq':        'QQ',
  'org.telegram.messenger':      'Telegram',
  'tw.nekomimi.nekogram':        'NekoGram',
  'top.qwq2333.nullgram':        'Nullgram',
  'com.discord':                 'Discord',
  'com.sina.weibo':              '微博',
  'com.zhihu.android':           '知乎',
  'com.xiaohongshu.android':     '小红书',
  'com.xingin.xhs':              '小红书（国际）',
  'com.douban.frodo':            '豆瓣',
  'com.instagram.android':       'Instagram',
  'com.twitter.android':         'X / Twitter',
  'com.facebook.katana':         'Facebook',
  'com.snapchat.android':        'Snapchat',
  'com.reddit.frontpage':        'Reddit',
  'com.linkedin.android':        'LinkedIn',
  'com.whatsapp':                'WhatsApp',
  'jp.naver.line.android':       'LINE',
  'com.xianbei.app':             '仙贝',
  'net.afdian.afdian':           '爱发电',
  // 短视频 / 长视频
  'com.ss.android.ugc.aweme':    '抖音',
  'com.ss.android.ugc.aweme.mobile': '抖音（极速版）',
  'com.kuaishou.nebula':         '快手',
  'tv.danmaku.bili':             '哔哩哔哩',
  'com.bilibili.app.in':         'Bilibili（国际）',
  'me.iacn.biliroaming':         'BiliRoaming（模块）',
  'com.google.android.youtube':  'YouTube',
  'com.netflix.mediaclient':     'Netflix',
  'tv.twitch.android.app':       'Twitch',
  'com.youku.phone':             '优酷',
  'com.iqiyi.video':             '爱奇艺',
  'com.mgtv.tv':                 '芒果TV',
  'com.tencent.qqlive':          '腾讯视频',
  'com.ss.android.article.video':'西瓜视频',
  'org.videolan.vlc':            'VLC',
  'com.mxtech.videoplayer.ad':   'MX Player',
  'dev.anilbeesetti.nextplayer': 'Next Player',
  // 游戏
  'com.nexon.bluearchive':       '蔚蓝档案',
  'com.tencent.tmgp.sgame':      '王者荣耀',
  'com.miHoYo.Yuanshen':         '原神',
  'com.mihoyo.hyperion':         '米游社',
  'com.hypergryph.endfield':     '明日方舟：终末地',
  'com.hypergryph.skland':       '森空岛',
  'com.PigeonGames.Phigros':     'Phigros',
  'com.mojang.minecraftpe':      'Minecraft',
  'com.valvesoftware.android.steam.community': 'Steam',
  'com.valvesoftware.steamlink': 'Steam Link',
  'com.epicgames.portal':        'Epic Games',
  'com.taptap':                  'TapTap',
  'com.max.xiaoheihe':           '小黑盒',
  'com.supercell.clashofclans':  '部落冲突',
  'com.supercell.clashroyale':   '皇室战争',
  'com.megacrit.sts2':           '杀戮尖塔2',
  'com.playstack.balatro.android':'Balatro',
  'org.ppsspp.ppsspp':           'PPSSPP模拟器',
  // 音乐
  'com.netease.cloudmusic':      '网易云音乐',
  'com.kugou.android':           '酷狗音乐',
  'com.tencent.qqmusic':         'QQ音乐',
  'com.kuwo.player':             '酷我音乐',
  'com.spotify.music':           'Spotify',
  'com.apple.android.music':     'Apple Music',
  'com.google.android.apps.youtube.music': 'YouTube Music',
  'io.stellio.music':            'Stellio',
  // 工作 / AI
  'com.openai.chatgpt':          'ChatGPT',
  'com.deepseek.chat':           'DeepSeek',
  'com.microsoft.copilot':       'Copilot',
  'com.google.android.apps.bard':'Gemini',
  'md.obsidian':                 'Obsidian',
  'net.cozic.joplin':            'Joplin',
  'com.ticktick.task':           '滴答清单',
  'com.alibaba.android.rimet':   '钉钉',
  'com.tencent.wework':          '企业微信',
  'com.github.android':          'GitHub',
  // 购物 / 金融
  'com.taobao.taobao':           '淘宝',
  'com.tmall.wireless':          '天猫',
  'com.taobao.idlefish':         '闲鱼',
  'com.jingdong.app.mall':       '京东',
  'com.xunmeng.pinduoduo':       '拼多多',
  'com.amazon.mShop.android.shopping': 'Amazon',
  'com.shizhuang.duapp':         '得物',
  'com.sankuai.meituan':         '美团',
  'ctrip.android.view':          '携程',
  'com.MobileTicket':            '铁路12306',
  'com.eg.android.AlipayGphone': '支付宝',
  // 教育
  'com.maimemo.android.momo':    '墨墨背单词',
  'com.shanbay.kaoyan':          '扇贝考研',
  'com.ichi2.anki':              'Anki',
  'com.amazon.kindle':           'Kindle',
};

class AppUsageEntry {
  final String package;
  final int ms;
  final String type;

  const AppUsageEntry({required this.package, required this.ms, required this.type});

  String get appName => _kNames[package] ?? _friendlyName(package);

  static String _friendlyName(String pkg) {
    final parts = pkg.split('.');
    if (parts.length < 2) return pkg;
    final last = parts.last;
    if (last.length <= 2) {
      final prev = parts[parts.length - 2];
      return prev[0].toUpperCase() + prev.substring(1);
    }
    return last[0].toUpperCase() + last.substring(1);
  }

  String get minutes => '${(ms / 60000).round()}分钟';
}

class UsageSummary {
  final List<AppUsageEntry> apps;
  final int totalSocialMs;
  final int totalVideoMs;
  final int totalGameMs;
  final int totalMusicMs;
  final int totalNewsMs;
  final int totalShoppingMs;
  final int totalCustomMs;
  final int totalEntertainMs;
  final int totalWorkMs;
  final int totalOtherMs;

  const UsageSummary({
    required this.apps,
    required this.totalSocialMs,
    required this.totalVideoMs,
    required this.totalGameMs,
    this.totalMusicMs = 0,
    this.totalNewsMs = 0,
    this.totalShoppingMs = 0,
    this.totalCustomMs = 0,
    required this.totalEntertainMs,
    this.totalWorkMs = 0,
    required this.totalOtherMs,
  });

  String get entertainMinutes => '${(totalEntertainMs / 60000).round()}';
  double entertainHours() => totalEntertainMs / 3600000;

  int efficiencyScore(int focusSecs) {
    final entertainH = entertainHours();
    final focusH = focusSecs / 3600;
    if (entertainH == 0 && focusH == 0) return 70;
    final ratio = focusH / (focusH + entertainH).clamp(0.01, 100);
    return (ratio * 100).clamp(0, 100).round();
  }
}

class UsageStatsService {
  static const _ch = MethodChannel('com.lsz.app/usage_stats');

  static Future<bool> hasPermission() async {
    try { return await _ch.invokeMethod('hasPermission') as bool; }
    catch (_) { return false; }
  }

  static Future<void> requestPermission() async {
    try { await _ch.invokeMethod('requestPermission'); } catch (_) {}
  }

  static Future<UsageSummary?> getTodayUsage({
    Map<String, String> userCategories = const {},
  }) async {
    try {
      final raw = await _ch.invokeMethod<Map>('getTodayUsage', {
        'userCategories': userCategories,
      });
      if (raw == null) return null;
      final appsRaw = (raw['apps'] as List?) ?? [];
      final apps = appsRaw.map((a) {
        final m = Map<String, dynamic>.from(a as Map);
        return AppUsageEntry(
          package: m['package'] as String,
          ms: (m['ms'] as num).toInt(),
          type: m['type'] as String,
        );
      }).toList();
      return UsageSummary(
        apps: apps,
        totalSocialMs:    (raw['totalSocialMs']    as num? ?? 0).toInt(),
        totalVideoMs:     (raw['totalVideoMs']     as num? ?? 0).toInt(),
        totalGameMs:      (raw['totalGameMs']      as num? ?? 0).toInt(),
        totalMusicMs:     (raw['totalMusicMs']     as num? ?? 0).toInt(),
        totalNewsMs:      (raw['totalNewsMs']      as num? ?? 0).toInt(),
        totalShoppingMs:  (raw['totalShoppingMs']  as num? ?? 0).toInt(),
        totalCustomMs:    (raw['totalCustomMs']    as num? ?? 0).toInt(),
        totalEntertainMs: (raw['totalEntertainMs'] as num? ?? 0).toInt(),
        totalWorkMs:      (raw['totalWorkMs']      as num? ?? 0).toInt(),
        totalOtherMs:     (raw['totalOtherMs']     as num? ?? 0).toInt(),
      );
    } catch (_) { return null; }
  }

  static Future<List<InstalledApp>> getInstalledApps() async {
    try {
      final raw = await _ch.invokeMethod<List>('getInstalledApps');
      if (raw == null) return [];
      return raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return InstalledApp(
          package: m['package'] as String,
          label: m['label'] as String,
          defaultCategory: m['defaultCategory'] as String,
        );
      }).toList();
    } catch (_) { return []; }
  }
}

class InstalledApp {
  final String package;
  final String label;
  final String defaultCategory;
  const InstalledApp({
    required this.package,
    required this.label,
    required this.defaultCategory,
  });
}

class DeviceInfoService {
  static const _ch = MethodChannel('com.lsz.app/device_info');
  static String? _brand;

  static Future<String> getBrand() async {
    if (_brand != null) return _brand!;
    try { _brand = await _ch.invokeMethod<String>('getBrand') ?? 'unknown'; }
    catch (_) { _brand = 'unknown'; }
    return _brand!;
  }
}
