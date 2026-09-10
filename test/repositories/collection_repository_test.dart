import 'package:flutter_test/flutter_test.dart';
import 'package:pokecardex_scanner_mvp/repositories/collection_repository.dart';

class _FakeCollectionStore implements CollectionStore {
  final List<Map<String, dynamic>> upsertCalls = [];

  @override
  Future<List<Map<String, dynamic>>> fetchCollections() async => const [];

  @override
  Future<List<Map<String, dynamic>>> fetchCollectionCards(String collectionId) async => const [];

  @override
  Future<Map<String, dynamic>> upsertCard({
    required String userId,
    required String collectionId,
    required String cardId,
    required String finish,
    required String condition,
    required int quantity,
  }) async {
    final call = {
      'userId': userId,
      'collectionId': collectionId,
      'cardId': cardId,
      'finish': finish,
      'condition': condition,
      'quantity': quantity,
    };
    upsertCalls.add(call);
    return call;
  }
}

void main() {
  test('addCardToCollection chama o upsert atômico com o usuário logado', () async {
    final store = _FakeCollectionStore();
    final repo = CollectionRepository(store: store, currentUserId: () => 'user-1');

    await repo.addCardToCollection(
      collectionId: 'c1',
      cardId: 'me01-091',
      finish: 'holo',
      quantity: 2,
    );

    expect(store.upsertCalls, hasLength(1));
    expect(store.upsertCalls.single, {
      'userId': 'user-1',
      'collectionId': 'c1',
      'cardId': 'me01-091',
      'finish': 'holo',
      'condition': 'NM',
      'quantity': 2,
    });
  });

  test('sem sessão logada: recusa em vez de gravar sem user_id', () async {
    final repo = CollectionRepository(store: _FakeCollectionStore(), currentUserId: () => null);
    expect(
      () => repo.addCardToCollection(collectionId: 'c1', cardId: 'me01-091', finish: 'holo'),
      throwsStateError,
    );
  });
}
