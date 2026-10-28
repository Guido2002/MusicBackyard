import 'package:flutter_test/flutter_test.dart';
import 'package:music_backyard/features/songs/domain/song.dart';
import 'package:music_backyard/features/tablature/tab_codec.dart';

void main() {
  test('ASCII roundtrip preserves string, slot, empty measures and tuning', () {
    final a = SongArrangement(
      name: 'Drop D',
      tuning: 'D A D G B e',
      measures: [
        TabMeasure(
          events: [
            TabEvent(string: 0, position: 0, value: '12'),
            TabEvent(string: 5, position: 7, value: '5h7'),
            TabEvent(string: 2, position: 3, value: r'9\7'),
            TabEvent(string: 3, position: 3, value: '<12>'),
          ],
        ),
        TabMeasure(),
        TabMeasure(events: [TabEvent(string: 1, position: 4, value: 'x')]),
      ],
    );
    final parsed = TabCodec.parse(TabCodec.encode(a));
    expect(parsed.tuning, a.tuning);
    expect(parsed.measures.length, 3);
    for (var i = 0; i < a.measures.length; i++) {
      final expected =
          a.measures[i].events
              .map((e) => '${e.string}:${e.position}:${e.value}')
              .toList()
            ..sort();
      final actual =
          parsed.measures[i].events
              .map((e) => '${e.string}:${e.position}:${e.value}')
              .toList()
            ..sort();
      expect(actual, expected);
    }
  });
  test('Conventional tabs preserve note positions and split long bars', () {
    final rows = ['e', 'B', 'G', 'D', 'A', 'E']
        .asMap()
        .entries
        .map(
          (e) => '${e.value}|${e.key == 0 ? '---0----7---' : '------------'}|',
        )
        .join('\n');
    final parsed = TabCodec.parse(rows);
    expect(parsed.measures.length, 2);
    expect(parsed.measures.first.events.single.position, 3);
    expect(parsed.measures.last.events.single.position, 0);
  });
  test('Repeated six-line blocks support comments and whitespace', () {
    final a = SongArrangement(
      name: 'A',
      measures: [
        TabMeasure(events: [TabEvent(string: 0, position: 1, value: '0')]),
      ],
    );
    final text = TabCodec.encode(a);
    expect(TabCodec.parse('# Own riff\n$text\n\n$text').measures.length, 2);
  });
  test('Malformed or ambiguous ASCII never produces a partial result', () {
    final valid = TabCodec.encode(
      SongArrangement(name: 'A', measures: [TabMeasure()]),
    );
    for (final input in [
      '',
      valid.split('\n').take(5).join('\n'),
      valid.replaceFirst('---', '--'),
      valid.replaceFirst('---', '99-'),
      valid.replaceFirst('---', 'abc'),
      '$valid\nNot a tab',
    ]) {
      expect(() => TabCodec.parse(input), throwsFormatException);
    }
  });
  test('Fret and technique validation includes technique target limits', () {
    for (final value in [
      '0',
      '24',
      'x',
      '5h7',
      '7p5',
      '7/9',
      r'9\7',
      '7b9',
      '7~',
      '<12>',
      '7.',
    ]) {
      expect(TabCodec.validValue(value), isTrue, reason: value);
    }
    for (final value in ['25', '5h99', '-1', '123', '7unknown', '']) {
      expect(TabCodec.validValue(value), isFalse, reason: value);
    }
    expect(TabCodec.validTuning(' D  A D G B e '), isTrue);
    expect(TabCodec.validTuning('E A D G B banana'), isFalse);
  });
}
