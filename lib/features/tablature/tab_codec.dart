import '../songs/domain/song.dart';

class ParsedTab {
  ParsedTab({required this.tuning, required this.measures});
  final String tuning;
  final List<TabMeasure> measures;
}

/// ASCII is an interchange format; stored events always use string/slot positions.
abstract final class TabCodec {
  static const slots = 8;
  static final _value = RegExp(
    r'^(?:<\d{1,2}>|\d{1,2}|x)(?:(?:[hp/\\b]\d{1,2})|[~v.<>])*$',
    caseSensitive: false,
  );
  static bool validTuning(String tuning) {
    final notes = tuning.trim().split(RegExp(r'\s+'));
    return notes.length == 6 &&
        notes.every((n) => RegExp(r'^[A-Ga-g](?:#|b)?$').hasMatch(n));
  }

  static bool validValue(String value) =>
      _value.hasMatch(value) &&
      RegExp(r'\d+').allMatches(value).every((m) => int.parse(m[0]!) <= 24);

  static String encode(SongArrangement arrangement) {
    final labels = arrangement.tuning
        .trim()
        .split(RegExp(r'\s+'))
        .reversed
        .toList();
    if (!validTuning(arrangement.tuning)) {
      throw const FormatException('Six tuning labels required');
    }
    final rows = [for (final label in labels) StringBuffer('$label|')];
    for (final measure in arrangement.measures) {
      final widths = List<int>.filled(slots, 3), events = <String, String>{};
      for (final event in measure.events) {
        if (event.string < 0 ||
            event.string >= 6 ||
            event.position < 0 ||
            event.position >= slots ||
            !validValue(event.value)) {
          throw const FormatException('Invalid tab event');
        }
        final key = '${event.string}:${event.position}';
        if (events.containsKey(key)) {
          throw const FormatException('Duplicate tab position');
        }
        events[key] = event.value;
        if (widths[event.position] < event.value.length + 1) {
          widths[event.position] = event.value.length + 1;
        }
      }
      // A uniform width lets the importer distinguish empty musical slots from padding.
      final width = widths.reduce((a, b) => a > b ? a : b);
      for (var string = 0; string < 6; string++) {
        for (var position = 0; position < slots; position++) {
          rows[string].write(
            (events['$string:$position'] ?? '').padRight(width, '-'),
          );
        }
        rows[string].write('|');
      }
    }
    return rows.join('\n');
  }

  static ParsedTab parse(String input) {
    if (input.length > 200000) {
      throw const FormatException('Tab too large');
    }
    final rows = input
        .replaceAll('\r\n', '\n')
        .split('\n')
        .where(
          (line) => line.trim().isNotEmpty && !line.trimLeft().startsWith('#'),
        )
        .toList();
    if (rows.isEmpty || rows.length % 6 != 0) {
      throw const FormatException('Expected six-string blocks');
    }
    final measures = <TabMeasure>[];
    List<String>? tuning;
    for (var block = 0; block < rows.length; block += 6) {
      final labels = <String>[], strings = <List<String>>[];
      for (final row in rows.skip(block).take(6)) {
        final match = RegExp(r'^\s*([A-Ga-g](?:#|b)?)\s*\|(.*)\|\s*$')
            .firstMatch(row);
        if (match == null) {
          throw const FormatException('Missing label or barline');
        }
        labels.add(match[1]!);
        strings.add(match[2]!.split('|'));
      }
      if (tuning != null &&
          labels.map((s) => s.toUpperCase()).join(' ') !=
              tuning.map((s) => s.toUpperCase()).join(' ')) {
        throw const FormatException('Mixed tunings');
      }
      tuning ??= labels;
      final barCount = strings.first.length;
      if (strings.any((s) => s.length != barCount)) {
        throw const FormatException('Unaligned barlines');
      }
      for (var bar = 0; bar < barCount; bar++) {
        final width = strings.first[bar].length;
        if (width == 0 ||
            width > 4096 ||
            strings.any((s) => s[bar].length != width)) {
          throw const FormatException('Unaligned strings');
        }
        final tokens = <({int string, int offset, String value})>[];
        for (var string = 0; string < 6; string++) {
          for (final token in RegExp(
            r'[^\s-]+',
          ).allMatches(strings[string][bar])) {
            final value = token[0]!;
            if (!validValue(value)) {
              throw const FormatException('Invalid fret or technique');
            }
            tokens.add((string: string, offset: token.start, value: value));
          }
        }
        final candidate = width % slots == 0 ? width ~/ slots : 1;
        final step =
            candidate > 1 &&
                tokens.every(
                  (t) =>
                      t.offset % candidate == 0 && t.value.length <= candidate,
                )
            ? candidate
            : 1;
        final count = (width / step / slots).ceil();
        if (measures.length + count > 1000) {
          throw const FormatException('Too many measures');
        }
        for (var part = 0; part < count; part++) {
          measures.add(
            TabMeasure(
              events: tokens
                  .where((t) => (t.offset ~/ step) ~/ slots == part)
                  .map(
                    (t) => TabEvent(
                      string: t.string,
                      position: (t.offset ~/ step) % slots,
                      value: t.value.toLowerCase(),
                    ),
                  )
                  .toList(),
            ),
          );
        }
      }
    }
    return ParsedTab(tuning: tuning!.reversed.join(' '), measures: measures);
  }
}
