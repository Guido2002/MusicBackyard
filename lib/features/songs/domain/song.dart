import 'dart:convert';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

Map<String, dynamic> _duplicateEntity(Map<String, dynamic> value) {
  final copy = jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  void renew(dynamic node) {
    if (node is Map) {
      if (node.containsKey('id')) {
        node['id'] = newId();
      }
      for (final child in node.values) {
        renew(child);
      }
    } else if (node is List) {
      for (final child in node) {
        renew(child);
      }
    }
  }

  renew(copy);
  return copy;
}

class ChordAnchor {
  ChordAnchor(this.offset, this.chord);
  int offset;
  String chord;
  Map<String, dynamic> toJson() => {'offset': offset, 'chord': chord};
  factory ChordAnchor.fromJson(Map<String, dynamic> j) =>
      ChordAnchor(j['offset'] as int, j['chord'] as String);
}

class LyricLine {
  LyricLine({String? id, this.text = '', List<ChordAnchor>? chords})
    : id = id ?? newId(),
      chords = chords ?? [];
  final String id;
  String text;
  List<ChordAnchor> chords;
  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'chords': chords.map((e) => e.toJson()).toList(),
  };
  factory LyricLine.fromJson(Map<String, dynamic> j) => LyricLine(
    id: j['id'],
    text: j['text'] ?? '',
    chords: (j['chords'] as List? ?? [])
        .map((e) => ChordAnchor.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

class SongSection {
  SongSection duplicate() => SongSection.fromJson(_duplicateEntity(toJson()));
  SongSection({String? id, required this.name, List<LyricLine>? lines})
    : id = id ?? newId(),
      lines = lines ?? [LyricLine()];
  final String id;
  String name;
  List<LyricLine> lines;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lines': lines.map((e) => e.toJson()).toList(),
  };
  factory SongSection.fromJson(Map<String, dynamic> j) => SongSection(
    id: j['id'],
    name: j['name'],
    lines: (j['lines'] as List)
        .map((e) => LyricLine.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

class TabEvent {
  TabEvent({required this.string, required this.position, required this.value});
  int string, position;
  String value;
  Map<String, dynamic> toJson() => {
    'string': string,
    'position': position,
    'value': value,
  };
  factory TabEvent.fromJson(Map<String, dynamic> j) =>
      TabEvent(string: j['string'], position: j['position'], value: j['value']);
}

class TabMeasure {
  TabMeasure({String? id, List<TabEvent>? events})
    : id = id ?? newId(),
      events = events ?? [];
  final String id;
  List<TabEvent> events;
  Map<String, dynamic> toJson() => {
    'id': id,
    'events': events.map((e) => e.toJson()).toList(),
  };
  factory TabMeasure.fromJson(Map<String, dynamic> j) => TabMeasure(
    id: j['id'],
    events: (j['events'] as List)
        .map((e) => TabEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

class SongArrangement {
  SongArrangement duplicate() =>
      SongArrangement.fromJson(_duplicateEntity(toJson()));
  SongArrangement({
    String? id,
    required this.name,
    List<SongSection>? sections,
    List<TabMeasure>? measures,
    this.tuning = 'E A D G B e',
  }) : id = id ?? newId(),
       sections = sections ?? [],
       measures = measures ?? [];
  final String id;
  String name, tuning;
  List<SongSection> sections;
  List<TabMeasure> measures;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tuning': tuning,
    'sections': sections.map((e) => e.toJson()).toList(),
    'measures': measures.map((e) => e.toJson()).toList(),
  };
  factory SongArrangement.fromJson(Map<String, dynamic> j) => SongArrangement(
    id: j['id'],
    name: j['name'],
    tuning: j['tuning'] ?? 'E A D G B e',
    sections: (j['sections'] as List)
        .map((e) => SongSection.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    measures: (j['measures'] as List? ?? [])
        .map((e) => TabMeasure.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

class Attachment {
  Attachment({
    String? id,
    required this.name,
    required this.path,
    required this.kind,
  }) : id = id ?? newId();
  final String id;
  String name, path, kind;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'kind': kind,
  };
  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
    id: j['id'],
    name: j['name'],
    path: j['path'],
    kind: j['kind'],
  );
}

class Song {
  Song({
    String? id,
    this.title = '',
    this.artist = '',
    this.album = '',
    this.genre = '',
    this.originalKey = 'C',
    this.currentKey = 'C',
    this.bpm = 100,
    this.timeSignature = '4/4',
    this.capo = 0,
    this.instrument = 'Gitaar',
    this.duration = 180,
    this.spotifyUrl = '',
    this.notes = '',
    this.comments = '',
    this.folderId,
    this.favorite = false,
    this.archived = false,
    this.deleted = false,
    List<String>? tags,
    List<SongArrangement>? arrangements,
    List<Attachment>? attachments,
    List<String>? directives,
    DateTime? updatedAt,
    this.openedAt,
  }) : id = id ?? newId(),
       tags = tags ?? [],
       arrangements =
           arrangements ??
           [
             SongArrangement(
               name: 'Origineel',
               sections: [SongSection(name: 'Couplet')],
             ),
           ],
       attachments = attachments ?? [],
       directives = directives ?? [],
       updatedAt = updatedAt ?? DateTime.now();
  final String id;
  String title,
      artist,
      album,
      genre,
      originalKey,
      currentKey,
      timeSignature,
      instrument,
      spotifyUrl,
      notes,
      comments;
  int bpm, capo, duration;
  String? folderId;
  bool favorite, archived, deleted;
  List<String> tags, directives;
  List<SongArrangement> arrangements;
  List<Attachment> attachments;
  DateTime updatedAt;
  DateTime? openedAt;
  String get searchable =>
      '$title $artist $notes $comments ${tags.join(' ')} ${arrangements.expand((a) => a.sections).expand((s) => s.lines).map((l) => l.text).join(' ')}'
          .toLowerCase();
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'genre': genre,
    'originalKey': originalKey,
    'currentKey': currentKey,
    'bpm': bpm,
    'timeSignature': timeSignature,
    'capo': capo,
    'instrument': instrument,
    'duration': duration,
    'spotifyUrl': spotifyUrl,
    'notes': notes,
    'comments': comments,
    'folderId': folderId,
    'favorite': favorite,
    'archived': archived,
    'deleted': deleted,
    'tags': tags,
    'directives': directives,
    'arrangements': arrangements.map((e) => e.toJson()).toList(),
    'attachments': attachments.map((e) => e.toJson()).toList(),
    'updatedAt': updatedAt.toIso8601String(),
    'openedAt': openedAt?.toIso8601String(),
  };
  factory Song.fromJson(Map<String, dynamic> j) => Song(
    id: j['id'],
    title: j['title'] ?? '',
    artist: j['artist'] ?? '',
    album: j['album'] ?? '',
    genre: j['genre'] ?? '',
    originalKey: j['originalKey'] ?? 'C',
    currentKey: j['currentKey'] ?? 'C',
    bpm: j['bpm'] ?? 100,
    timeSignature: j['timeSignature'] ?? '4/4',
    capo: j['capo'] ?? 0,
    instrument: j['instrument'] ?? 'Gitaar',
    duration: j['duration'] ?? 180,
    spotifyUrl: j['spotifyUrl'] ?? '',
    notes: j['notes'] ?? '',
    comments: j['comments'] ?? '',
    folderId: j['folderId'],
    favorite: j['favorite'] ?? false,
    archived: j['archived'] ?? false,
    deleted: j['deleted'] ?? false,
    tags: List<String>.from(j['tags'] ?? []),
    directives: List<String>.from(j['directives'] ?? []),
    arrangements: (j['arrangements'] as List)
        .map((e) => SongArrangement.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    attachments: (j['attachments'] as List? ?? [])
        .map((e) => Attachment.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    updatedAt: DateTime.tryParse(j['updatedAt'] ?? ''),
    openedAt: DateTime.tryParse(j['openedAt'] ?? ''),
  );
  Song clone({bool newIdentity = false, String? arrangementId}) {
    final source = toJson();
    if (arrangementId != null) {
      final selected = arrangements
          .where((a) => a.id == arrangementId)
          .firstOrNull;
      if (selected == null) {
        throw ArgumentError('Unknown arrangement');
      }
      source['arrangements'] = [selected.toJson()];
    }
    final j = newIdentity
        ? _duplicateEntity(source)
        : jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
    if (newIdentity) {
      j['id'] = newId();
      j['title'] = '$title (kopie)';
      j['favorite'] = false;
      j['deleted'] = false;
      j['openedAt'] = null;
    }
    return Song.fromJson(j);
  }
}

class Folder {
  Folder({String? id, required this.name, this.parentId}) : id = id ?? newId();
  final String id;
  String name;
  String? parentId;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'parentId': parentId,
  };
  factory Folder.fromJson(Map<String, dynamic> j) =>
      Folder(id: j['id'], name: j['name'], parentId: j['parentId']);
}

class SetlistEntry {
  SetlistEntry({
    String? id,
    this.songId,
    this.arrangementId,
    this.transpose = 0,
    this.capo,
    this.breakSeconds = 0,
    this.note = '',
  }) : id = id ?? newId();
  final String id;
  String? songId, arrangementId;
  int transpose, breakSeconds;
  int? capo;
  String note;
  Map<String, dynamic> toJson() => {
    'id': id,
    'songId': songId,
    'arrangementId': arrangementId,
    'transpose': transpose,
    'capo': capo,
    'breakSeconds': breakSeconds,
    'note': note,
  };
  factory SetlistEntry.fromJson(Map<String, dynamic> j) => SetlistEntry(
    id: j['id'],
    songId: j['songId'],
    arrangementId: j['arrangementId'],
    transpose: j['transpose'] ?? 0,
    capo: j['capo'],
    breakSeconds: j['breakSeconds'] ?? 0,
    note: j['note'] ?? '',
  );
}

class MusicSetlist {
  MusicSetlist({
    String? id,
    required this.name,
    this.notes = '',
    List<SetlistEntry>? entries,
  }) : id = id ?? newId(),
       entries = entries ?? [];
  final String id;
  String name, notes;
  List<SetlistEntry> entries;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'notes': notes,
    'entries': entries.map((e) => e.toJson()).toList(),
  };
  factory MusicSetlist.fromJson(Map<String, dynamic> j) => MusicSetlist(
    id: j['id'],
    name: j['name'],
    notes: j['notes'] ?? '',
    entries: (j['entries'] as List)
        .map((e) => SetlistEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}
