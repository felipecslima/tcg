import 'package:flutter_test/flutter_test.dart';
import 'package:pokecardex_scanner_mvp/repositories/collection_repository.dart';

class _FakeCollectionStore implements CollectionStore {
  final List<Map<String, dynamic>> upsertCalls = [];

  @override
  Future<List<Map<String, dynamic>>> fetchCollections() async => const [];

  @override
  Future<List<Map<String, dynamic>>> fetchCollectionCards(String collectionId) async => const [];

  @override
  Future<List<String>> fetchCardIdsInSet(String setId) async => const [];

  @override
  Future<List<String>> fetchOwnedCardIds(List<String> cardIds) async => const [];

  @override
  Future<List<Map<String, dynamic>>> fetchOwnedQuantities(List<String> cardIds) async => const [];

  @override
  Future<List<String>> fetchAllOwnedCardIds() async => const [];

  @override
  Future<List<int>> fetchOwnedNationalDexIds() async => const [];

  @override
  Future<Map<String, dynamic>> upsertCard({
    required String userId,
    required String collectionId,
    required String cardId,
    required String finish,
    required String condition,
    required int quantity,
    String language = 'pt',
  }) async {
    final call = {
      'userId': userId,
      'collectionId': collectionId,
      'cardId': cardId,
      'finish': finish,
      'condition': condition,
      'quantity': quantity,
      'language': language,
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
      'language': 'pt',
    });
  });

  test('addCardsBatch grava sequencialmente cada entrada', () async {
    final store = _FakeCollectionStore();
    final repo = CollectionRepository(store: store, currentUserId: () => 'user-1');

    final saved = await repo.addCardsBatch(
      collectionId: 'c1',
      entries: [
        (cardId: 'card-a', finish: 'normal', quantity: 1, language: 'pt'),
        (cardId: 'card-b', finish: 'holo', quantity: 2, language: 'pt'),
        (cardId: 'card-c', finish: 'reverse', quantity: 1, language: 'en'),
      ],
    );

    expect(saved, 3);
    expect(store.upsertCalls, hasLength(3));
    expect(store.upsertCalls[0]['cardId'], 'card-a');
    expect(store.upsertCalls[1]['cardId'], 'card-b');
    expect(store.upsertCalls[1]['finish'], 'holo');
    expect(store.upsertCalls[1]['quantity'], 2);
    expect(store.upsertCalls[2]['finish'], 'reverse');
  });

  test('sem sessão logada: recusa em vez de gravar sem user_id', () async {
    final repo = CollectionRepository(store: _FakeCollectionStore(), currentUserId: () => null);
    expect(
      () => repo.addCardToCollection(collectionId: 'c1', cardId: 'me01-091', finish: 'holo'),
      throwsStateError,
    );
  });
}
