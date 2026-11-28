// A person's own free-named tags on a day, and which past ones to offer
// again. Two tags that differ only in case are the same tag.

import 'package:lilith/domain/daily_log.dart';

/// The longest a tag can be.
const int maxTagLength = 30;

/// The most tags one day holds.
const int maxTagsPerDay = 10;

/// The most past tags offered at once.
const int maxTagSuggestions = 8;

final RegExp _joiners = RegExp('[,;]');
final RegExp _spaces = RegExp(r'\s+');

String _fold(String tag) => tag.toLowerCase();

int _aToZ(String a, String b) {
  final byLetters = _fold(a).compareTo(_fold(b));
  return byLetters != 0 ? byLetters : a.compareTo(b);
}

/// [raw] as it is stored, or null when nothing is left of it: trimmed,
/// spaces closed up, no longer than [maxTagLength], and without the commas
/// and semicolons the summary and the CSV join tags with.
String? cleanTag(String raw) {
  final spaced = raw.replaceAll(_joiners, ' ').replaceAll(_spaces, ' ').trim();
  final cut = spaced.length > maxTagLength
      ? spaced.substring(0, maxTagLength).trim()
      : spaced;
  return cut.isEmpty ? null : cut;
}

/// [tags] as a day holds them: each cleaned, the first kept of any that
/// differ only in case, at most [maxTagsPerDay], A to Z. Anything that is
/// not text is skipped.
List<String> cleanTags(Iterable<Object?> tags) {
  final kept = <String, String>{};
  for (final raw in tags) {
    if (kept.length == maxTagsPerDay) break;
    final tag = raw is String ? cleanTag(raw) : null;
    if (tag != null) kept.putIfAbsent(_fold(tag), () => tag);
  }
  return List.unmodifiable(kept.values.toList()..sort(_aToZ));
}

/// [tags] with [raw] added; unchanged when [raw] is blank, already there,
/// or the day is full.
List<String> withTag(List<String> tags, String raw) =>
    cleanTags([...tags, raw]);

/// [tags] without [tag], whatever its case.
List<String> withoutTag(List<String> tags, String tag) {
  final gone = _fold(cleanTag(tag) ?? '');
  return cleanTags(tags.where((t) => _fold(t) != gone));
}

/// How often each tag of [logs] was used, under the spelling of the latest
/// day that has it.
Map<String, ({String spelling, int days})> _used(Iterable<DailyLog> logs) {
  final byDate = logs.toList()..sort((a, b) => a.date.compareTo(b.date));
  final used = <String, ({String spelling, int days})>{};
  for (final log in byDate) {
    for (final tag in log.signs.tags) {
      final days = used[_fold(tag)]?.days ?? 0;
      used[_fold(tag)] = (spelling: tag, days: days + 1);
    }
  }
  return used;
}

/// The spelling [raw] was last logged with in [logs], or null when it
/// never was.
String? knownSpelling(Iterable<DailyLog> logs, String raw) {
  final tag = cleanTag(raw);
  return tag == null ? null : _used(logs)[_fold(tag)]?.spelling;
}

/// The past tags of [logs] to offer, at most [max]: those holding [typed],
/// the ones that start with it first, then the most used, then A to Z.
/// Tags in [chosen] are left out.
List<String> tagSuggestions(
  Iterable<DailyLog> logs, {
  String typed = '',
  Iterable<String> chosen = const [],
  int max = maxTagSuggestions,
}) {
  final text = _fold(cleanTag(typed) ?? '');
  final taken = {for (final c in chosen) _fold(c)};
  final offered = [
    for (final e in _used(logs).entries)
      if (!taken.contains(e.key) && e.key.contains(text)) e,
  ];
  int rank(String folded) => folded.startsWith(text) ? 0 : 1;
  offered.sort((a, b) {
    final byStart = rank(a.key).compareTo(rank(b.key));
    if (byStart != 0) return byStart;
    final byUse = b.value.days.compareTo(a.value.days);
    return byUse != 0 ? byUse : _aToZ(a.value.spelling, b.value.spelling);
  });
  return [for (final e in offered.take(max)) e.value.spelling];
}
