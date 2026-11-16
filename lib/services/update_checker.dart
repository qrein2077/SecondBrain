import 'dart:convert';

import 'package:http/http.dart' as http;

/// Checks GitHub Releases first, then falls back to Actions workflow URL.
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    this.latestTag,
    this.releaseUrl,
    this.downloadUrl,
    this.actionsUrl =
        'https://github.com/qrein2077/SecondBrain/actions/workflows/windows-installer.yml',
    this.message = '',
    this.hasUpdate = false,
  });

  final String currentVersion;
  final String? latestTag;
  final String? releaseUrl;
  final String? downloadUrl;
  final String actionsUrl;
  final String message;
  final bool hasUpdate;
}

class UpdateChecker {
  UpdateChecker({
    this.owner = 'qrein2077',
    this.repo = 'SecondBrain',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String owner;
  final String repo;
  final http.Client _client;

  static const actionsWorkflowUrl =
      'https://github.com/qrein2077/SecondBrain/actions/workflows/windows-installer.yml';

  Future<UpdateCheckResult> check({required String currentVersion}) async {
    final normalizedCurrent = _normalizeVersion(currentVersion);
    try {
      final uri = Uri.parse(
        'https://api.github.com/repos/$owner/$repo/releases/latest',
      );
      final res = await _client.get(
        uri,
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'SecondBrain-UpdateChecker',
        },
      );

      if (res.statusCode == 404) {
        return UpdateCheckResult(
          currentVersion: normalizedCurrent,
          message:
              'GitHub Release ещё не опубликован. Скачайте установщик из Actions '
              '(артефакт SecondBrain-Setup-Windows).',
          actionsUrl: actionsWorkflowUrl,
        );
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return UpdateCheckResult(
          currentVersion: normalizedCurrent,
          message:
              'Не удалось проверить Releases (HTTP ${res.statusCode}). '
              'Откройте Actions вручную.',
          actionsUrl: actionsWorkflowUrl,
        );
      }

      final map = jsonDecode(res.body);
      if (map is! Map) {
        return UpdateCheckResult(
          currentVersion: normalizedCurrent,
          message: 'Некорректный ответ GitHub Releases.',
          actionsUrl: actionsWorkflowUrl,
        );
      }

      final tag = (map['tag_name'] as String? ?? '').trim();
      final htmlUrl = map['html_url'] as String?;
      String? exeUrl;
      final assets = map['assets'];
      if (assets is List) {
        for (final a in assets) {
          if (a is! Map) continue;
          final name = (a['name'] as String? ?? '').toLowerCase();
          if (name.endsWith('.exe') && name.contains('secondbrain')) {
            exeUrl = a['browser_download_url'] as String?;
            break;
          }
        }
        if (exeUrl == null) {
          for (final a in assets) {
            if (a is! Map) continue;
            final name = (a['name'] as String? ?? '').toLowerCase();
            if (name.endsWith('.exe')) {
              exeUrl = a['browser_download_url'] as String?;
              break;
            }
          }
        }
      }

      final latest = _normalizeVersion(tag);
      final newer = _isNewer(latest, normalizedCurrent);
      return UpdateCheckResult(
        currentVersion: normalizedCurrent,
        latestTag: tag.isEmpty ? null : tag,
        releaseUrl: htmlUrl,
        downloadUrl: exeUrl,
        hasUpdate: newer,
        message: newer
            ? 'Доступна версия $tag (у вас $normalizedCurrent).'
            : tag.isEmpty
                ? 'Release найден, но без tag_name.'
                : 'У вас актуальная версия ($normalizedCurrent). Последний Release: $tag.',
        actionsUrl: actionsWorkflowUrl,
      );
    } catch (e) {
      return UpdateCheckResult(
        currentVersion: normalizedCurrent,
        message: 'Ошибка проверки обновлений: $e',
        actionsUrl: actionsWorkflowUrl,
      );
    }
  }

  static String _normalizeVersion(String v) {
    var s = v.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    final plus = s.indexOf('+');
    if (plus >= 0) s = s.substring(0, plus);
    return s;
  }

  /// True if [a] is strictly newer than [b] (semver-ish major.minor.patch).
  static bool isNewer(String a, String b) => _isNewer(a, b);

  static bool _isNewer(String a, String b) {
    List<int> parts(String v) {
      final out = <int>[];
      for (final p in v.split('.')) {
        out.add(int.tryParse(p.replaceAll(RegExp(r'[^0-9].*$'), '')) ?? 0);
      }
      while (out.length < 3) {
        out.add(0);
      }
      return out.take(3).toList();
    }

    final pa = parts(a);
    final pb = parts(b);
    for (var i = 0; i < 3; i++) {
      if (pa[i] > pb[i]) return true;
      if (pa[i] < pb[i]) return false;
    }
    return false;
  }
}
