/// Obsidian-style `[[wiki-link]]` helpers.
class WikiLink {
  static final pattern = RegExp(r'\[\[([^\[\]]+)\]\]');

  /// Target path/title from `[[path|alias]]` or `[[path]]`.
  static String targetOf(String inner) {
    final pipe = inner.indexOf('|');
    final raw = (pipe >= 0 ? inner.substring(0, pipe) : inner).trim();
    return raw;
  }

  static String displayOf(String inner) {
    final pipe = inner.indexOf('|');
    if (pipe >= 0) return inner.substring(pipe + 1).trim();
    return inner.trim();
  }

  /// Resolve wiki target against vault-relative `.md` paths.
  static String? resolve(String target, List<String> markdownFiles) {
    if (target.isEmpty || markdownFiles.isEmpty) return null;
    var t = target.replaceAll('\\', '/').trim();

    String? findExact(String want) {
      final lower = want.toLowerCase();
      for (final f in markdownFiles) {
        if (f.toLowerCase() == lower) return f;
      }
      return null;
    }

    final exact = findExact(t) ??
        (t.toLowerCase().endsWith('.md') ? null : findExact('$t.md'));
    if (exact != null) return exact;

    final base = t.split('/').last.toLowerCase();
    final baseMd = base.endsWith('.md') ? base : '$base.md';
    for (final f in markdownFiles) {
      final name = f.split('/').last.toLowerCase();
      if (name == baseMd || name == base) return f;
    }

    final q = baseMd.endsWith('.md')
        ? baseMd.substring(0, baseMd.length - 3)
        : baseMd;
    for (final f in markdownFiles) {
      final name = f.split('/').last.toLowerCase();
      final stem =
          name.endsWith('.md') ? name.substring(0, name.length - 3) : name;
      if (stem.contains(q) || q.contains(stem)) return f;
    }
    return null;
  }
}
