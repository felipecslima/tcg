import 'package:flutter_test/flutter_test.dart';
import 'package:pokecardex_scanner_mvp/models/card.dart';
import 'package:pokecardex_scanner_mvp/state/batch_session.dart';

Card _card(String id, {String setId = 's1', String name = 'Pikachu'}) => Card(
      id: id,
      setId: setId,
      localId: '025',
      name: name,
    );

void main() {
  late BatchSession session;

  setUp(() => session = BatchSession());

  test('add insere carta na sessão', () {
    session.add(_card('c1'));
    expect(session.distinctCount, 1);
    expect(session.count, 1);
    expect(session.entries.first.card.id, 'c1');
  });

  test('dedup: mesma carta+finish incrementa quantity', () {
    session.add(_card('c1'));
    session.add(_card('c1'));
    expect(session.distinctCount, 1);
    expect(session.count, 2);
    expect(session.entries.first.quantity, 2);
  });

  test('dedup: mesma carta com finish diferente não deduplica', () {
    session.add(_card('c1'), finish: 'normal');
    session.add(_card('c1'), finish: 'holo');
    expect(session.distinctCount, 2);
    expect(session.count, 2);
  });

  test('removeAt remove a carta correta', () {
    session.add(_card('c1'));
    session.add(_card('c2'));
    session.removeAt(0);
    expect(session.distinctCount, 1);
    expect(session.entries.first.card.id, 'c2');
  });

  test('removeAt com índice inválido não faz nada', () {
    session.add(_card('c1'));
    session.removeAt(5);
    expect(session.distinctCount, 1);
  });

  test('updateEntry altera finish e quantity', () {
    session.add(_card('c1'));
    session.updateEntry(0, finish: 'holo', quantity: 3);
    expect(session.entries.first.finish, 'holo');
    expect(session.entries.first.quantity, 3);
  });

  test('updateEntry: quantity clampado em 1–99', () {
    session.add(_card('c1'));
    session.updateEntry(0, quantity: 0);
    expect(session.entries.first.quantity, 1);
    session.updateEntry(0, quantity: 200);
    expect(session.entries.first.quantity, 99);
  });

  test('clear limpa todas as entradas', () {
    session.add(_card('c1'));
    session.add(_card('c2'));
    session.clear();
    expect(session.isEmpty, true);
    expect(session.count, 0);
  });

  test('limite de 50 entradas', () {
    for (var i = 0; i < 55; i++) {
      session.add(_card('c$i'));
    }
    expect(session.distinctCount, BatchSession.maxEntries);
  });

  test('isFull retorna true no limite', () {
    for (var i = 0; i < BatchSession.maxEntries; i++) {
      session.add(_card('c$i'));
    }
    expect(session.isFull, true);
  });

  test('notifyListeners é chamado ao modificar', () {
    var notified = 0;
    session.addListener(() => notified++);
    session.add(_card('c1'));
    session.updateEntry(0, finish: 'reverse');
    session.removeAt(0);
    session.clear();
    expect(notified, 4);
  });
}
