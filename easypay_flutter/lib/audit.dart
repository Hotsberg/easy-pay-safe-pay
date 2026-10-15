// Safety history: an append-only, hash-chained record of every safety check, warning overridden, payment and
// settings change. Each entry stores the SHA-256 of the previous one, so editing or deleting an old entry breaks
// the chain and the History screen says so. Pure Dart, no Flutter imports, so it runs in plain Dart tests.

import 'dart:convert';

import 'package:crypto/crypto.dart';

class LogEntry {
  final int t; // milliseconds since epoch
  final String kind; // check, override, stopped, paid, qrBlocked, setting
  final Map<String, Object?> data;
  final String prev, hash;

  const LogEntry(this.t, this.kind, this.data, this.prev, this.hash);

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(t);

  Map<String, Object?> toJson() => {'t': t, 'k': kind, 'd': data, 'p': prev, 'h': hash};

  static LogEntry fromJson(Map<String, dynamic> j) =>
      LogEntry((j['t'] as num).toInt(), '${j['k']}', Map<String, Object?>.from(j['d'] as Map), '${j['p']}', '${j['h']}');
}

const genesis = '0000000000000000000000000000000000000000000000000000000000000000';

String entryHash(String prev, int t, String kind, Map<String, Object?> data) =>
    sha256.convert(utf8.encode('$prev|$t|$kind|${jsonEncode(data)}')).toString();

class AuditLog {
  /// Hash the oldest kept entry points back to (moves forward when old entries are trimmed).
  String anchor;
  final List<LogEntry> entries;
  final int max;

  AuditLog({this.anchor = genesis, List<LogEntry>? entries, this.max = 300}) : entries = entries ?? [];

  LogEntry add(String kind, Map<String, Object?> data, {DateTime? at}) {
    final t = (at ?? DateTime.now()).millisecondsSinceEpoch;
    final prev = entries.isEmpty ? anchor : entries.last.hash;
    final e = LogEntry(t, kind, data, prev, entryHash(prev, t, kind, data));
    entries.add(e);
    while (entries.length > max) {
      anchor = entries.removeAt(0).hash;
    }
    return e;
  }

  /// Index of the first entry that was changed, removed or reordered, or -1 when the history is intact.
  int firstBroken() {
    var prev = anchor;
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (e.prev != prev || entryHash(e.prev, e.t, e.kind, e.data) != e.hash) return i;
      prev = e.hash;
    }
    return -1;
  }

  bool get intact => firstBroken() < 0;

  /// Money that left (or may have left) the account since midnight, in this mode.
  int paidSince(DateTime from, String mode) => entries
      .where((e) => e.kind == 'paid' && e.data['mode'] == mode && e.data['status'] != 'failure' && !e.time.isBefore(from))
      .fold(0, (a, e) => a + ((e.data['amt'] as num?)?.toInt() ?? 0));

  int paymentsSince(DateTime from, String mode) => entries
      .where((e) => e.kind == 'paid' && e.data['mode'] == mode && e.data['status'] != 'failure' && !e.time.isBefore(from))
      .length;

  String encode() => jsonEncode({'anchor': anchor, 'entries': entries.map((e) => e.toJson()).toList()});

  static AuditLog decode(String? raw) {
    if (raw == null || raw.isEmpty) return AuditLog();
    try {
      final v = jsonDecode(raw) as Map<String, dynamic>;
      return AuditLog(
        anchor: '${v['anchor'] ?? genesis}',
        entries: ((v['entries'] as List?) ?? []).map((e) => LogEntry.fromJson(e as Map<String, dynamic>)).toList(),
      );
    } catch (_) {
      // Unreadable history is itself a sign of tampering: keep a marker so the screen reports it
      return AuditLog(entries: [const LogEntry(0, 'corrupt', {}, 'x', 'x')]);
    }
  }
}
