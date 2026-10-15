// Safety history: the hash chain notices edits, deletions and reordering.
import 'package:flutter_test/flutter_test.dart';
import 'package:safepay/audit.dart';

AuditLog _three() {
  final l = AuditLog();
  final t0 = DateTime(2026, 10, 14, 10);
  l.add('check', {'payee': 'Raju', 'amt': 200, 'level': 'green', 'mode': 'practice'}, at: t0);
  l.add('paid', {'payee': 'Raju', 'amt': 200, 'status': 'success', 'mode': 'practice'}, at: t0.add(const Duration(minutes: 1)));
  l.add('check', {'payee': 'SBI Refund', 'amt': 15000, 'level': 'red', 'mode': 'practice'}, at: t0.add(const Duration(minutes: 5)));
  return l;
}

void main() {
  test('an untouched history verifies', () {
    expect(_three().intact, isTrue);
  });

  test('editing an amount is detected at that entry', () {
    final l = _three();
    final e = l.entries[1];
    l.entries[1] = LogEntry(e.t, e.kind, {...e.data, 'amt': 20}, e.prev, e.hash);
    expect(l.firstBroken(), 1);
  });

  test('deleting an entry is detected', () {
    final l = _three()..entries.removeAt(1);
    expect(l.firstBroken(), 1);
  });

  test('re-hashing an edited entry still breaks the next link', () {
    final l = _three();
    final e = l.entries[0];
    final data = {...e.data, 'level': 'red'};
    l.entries[0] = LogEntry(e.t, e.kind, data, e.prev, entryHash(e.prev, e.t, e.kind, data));
    expect(l.firstBroken(), 1);
  });

  test('survives saving and loading, and trimming old entries', () {
    final l = AuditLog(max: 5);
    for (var i = 0; i < 12; i++) {
      l.add('check', {'n': i});
    }
    expect(l.entries.length, 5);
    final back = AuditLog.decode(l.encode());
    expect(back.intact, isTrue);
    expect(back.entries.first.data['n'], 7);
  });

  test('unreadable history is reported, not silently reset', () {
    expect(AuditLog.decode('{not json').intact, isFalse);
  });

  test('payments today and in the last hour, per mode', () {
    final l = _three();
    final day = DateTime(2026, 10, 14);
    expect(l.paidSince(day, 'practice'), 200);
    expect(l.paidSince(day, 'real'), 0);
    expect(l.paymentsSince(day, 'practice'), 1);
  });
}
