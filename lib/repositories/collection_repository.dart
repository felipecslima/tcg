import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/card.dart';

/// Um binder da usuária (Minhas cartas / Deck / Para trocar), de `collections`.
class UserCollection {
  const UserCollection({
    required this.id,
    required this.name,
    required this.kind,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String kind;
  final int sortOrder;

  factory UserCollection.fromSupabaseRow(Map<String, dynamic> row) => UserCollection(
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        kind: row['kind'] as String? ?? 'custom',
        sortOrder: row['sort_order'] as int? ?? 0,
      );
}

/// Uma carta dentro de um binder — junta `collection_cards` com o catálogo
/// (`cards`) pra já vir com nome/arte/número prontos pra tela.
class CollectionCardEntry {
  const CollectionCardEntry({
    required this.id,
    required this.collectionId,
    required this.card,
    required this.finish,
    required this.condition,
    required this.quantity,
  });

  final String id;
  final String collectionId;
  final Card card;
  final String finish; // normal / reverse / holo
  final String condition; // NM, LP, ...
  final int quantity;

  factory CollectionCardEntry.fromSupabaseRow(Map<String, dynamic> row) => CollectionCardEntry(
        id: row['id'] as String,
        collectionId: row['collection_id'] as String,
        card: Card.fromSupabaseRow(row['cards'] as Map<String, dynamic>),
        finish: row['finish'] as String? ?? 'normal',
        condition: row['condition'] as String? ?? 'NM',
        quantity: row['quantity'] as int? ?? 1,
      );
}

/// Abstração fina sobre `collections`/`collection_cards` — permite fake em
/// teste. RLS já filtra por `auth.uid()` nas leituras; o upsert precisa do
/// `user_id` explícito.
abstract class CollectionStore {
  Future<List<Map<String, dynamic>>> fetchCollections();
  Future<List<Map<String, dynamic>>> fetchCollectionCards(String collectionId);
  Future<List<String>> fetchCardIdsInSet(String setId);
  Future<List<String>> fetchOwnedCardIds(List<String> cardIds);
  Future<List<Map<String, dynamic>>> fetchOwnedQuantities(List<String> cardIds);
  Future<List<String>> fetchAllOwnedCardIds();
  Future<Map<String, dynamic>> upsertCard({
    required String userId,
    required String collectionId,
    required String cardId,
    required String finish,
    required String condition,
    required int quantity,
  });
}

class SupabaseCollectionStore implements CollectionStore {
  SupabaseCollectionStore(this._client);
  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> fetchCollections() async {
    final rows = await _client.from('collections').select().order('sort_order');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCollectionCards(String collectionId) async {
    final rows = await _client
        .from('collection_cards')
        .select('*, cards(*)')
        .eq('collection_id', collectionId)
        .order('added_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<List<String>> fetchCardIdsInSet(String setId) async {
    final rows = await _client.from('cards').select('id').eq('set_id', setId);
    return (rows as List).map((r) => r['id'] as String).toList();
  }

  @override
  Future<List<String>> fetchOwnedCardIds(List<String> cardIds) async {
    if (cardIds.isEmpty) return const [];
    final rows =
        await _client.from('collection_cards').select('card_id').inFilter('card_id', cardIds);
    return (rows as List).map((r) => r['card_id'] as String).toSet().toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchOwnedQuantities(List<String> cardIds) async {
    if (cardIds.isEmpty) return const [];
    final rows = await _client
        .from('collection_cards')
        .select('card_id, quantity')
        .inFilter('card_id', cardIds);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<List<String>> fetchAllOwnedCardIds() async {
    final rows = await _client.from('collection_cards').select('card_id');
    return (rows as List).map((r) => r['card_id'] as String).toSet().toList();
  }

  /// Chama `upsert_collection_card` (migration `12_collection_cards_upsert`)
  /// — insert + `ON CONFLICT (collection_id, card_id, finish, condition) DO
  /// UPDATE quantity = quantity + excluded.quantity`, atômico no banco. Sem
  /// isso, um select-then-write no cliente tem race condition (duas
  /// escritas simultâneas podem duplicar linha ou perder quantidade).
  @override
  Future<Map<String, dynamic>> upsertCard({
    required String userId,
    required String collectionId,
    required String cardId,
    required String finish,
    required String condition,
    required int quantity,
  }) async {
    final row = await _client.rpc('upsert_collection_card', params: {
      'p_user_id': userId,
      'p_collection_id': collectionId,
      'p_card_id': cardId,
      'p_finish': finish,
      'p_condition': condition,
      'p_quantity': quantity,
    });
    return row as Map<String, dynamic>;
  }
}

/// Coleção da usuária — não tem noção de "TTL"/API: é dado 100% nosso,
/// sempre lido/escrito direto no Supabase (RLS garante isolamento por
/// usuário). O dedup de finish+condition repetido pra mesma carta é feito
/// no banco (constraint `UNIQUE` + upsert atômico via RPC), não no cliente.
class CollectionRepository {
  CollectionRepository({CollectionStore? store, SupabaseClient? client, String? Function()? currentUserId})
      : _store = store ?? SupabaseCollectionStore(client ?? Supabase.instance.client),
        // lazy: só toca `Supabase.instance` quando de fato chamado, pra não
        // exigir Supabase inicializado só pra construir o repositório (teste).
        _currentUserId =
            currentUserId ?? (() => (client ?? Supabase.instance.client).auth.currentUser?.id);

  final CollectionStore _store;
  final String? Function() _currentUserId;

  Future<List<UserCollection>> fetchUserCollections() async {
    final rows = await _store.fetchCollections();
    return rows.map(UserCollection.fromSupabaseRow).toList();
  }

  Future<List<CollectionCardEntry>> fetchCollectionCards(String collectionId) async {
    final rows = await _store.fetchCollectionCards(collectionId);
    return rows.map(CollectionCardEntry.fromSupabaseRow).toList();
  }

  /// Quantas cartas distintas do set a usuária já tem (qualquer binder) —
  /// usado na barra de progresso da tela Escolher coleção.
  Future<int> countOwnedInSet(String setId) async {
    final allIds = await _store.fetchCardIdsInSet(setId);
    if (allIds.isEmpty) return 0;
    final owned = await _store.fetchOwnedCardIds(allIds);
    return owned.length;
  }

  /// Todos os card_ids que a usuária possui (qualquer binder).
  Future<Set<String>> fetchAllOwnedCardIds() async {
    final ids = await _store.fetchAllOwnedCardIds();
    return ids.toSet();
  }

  /// Mapa card_id → quantidade total (soma de todos os binders).
  Future<Map<String, int>> ownedQuantityByCardId(List<String> cardIds) async {
    final rows = await _store.fetchOwnedQuantities(cardIds);
    final map = <String, int>{};
    for (final r in rows) {
      final id = r['card_id'] as String;
      final qty = r['quantity'] as int? ?? 1;
      map[id] = (map[id] ?? 0) + qty;
    }
    return map;
  }

  /// Adiciona (ou soma quantidade a) uma carta num binder — o "Salvar na
  /// coleção" da tela Confirmar.
  Future<void> addCardToCollection({
    required String collectionId,
    required String cardId,
    required String finish,
    String condition = 'NM',
    int quantity = 1,
  }) async {
    final userId = _currentUserId();
    if (userId == null) {
      throw StateError('addCardToCollection chamado sem sessão logada');
    }
    await _store.upsertCard(
      userId: userId,
      collectionId: collectionId,
      cardId: cardId,
      finish: finish,
      condition: condition,
      quantity: quantity.clamp(1, 99),
    );
  }
}
