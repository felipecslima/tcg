import 'package:supabase_flutter/supabase_flutter.dart';

/// Uma região (Kanto, Johto, ...), lida de `regions`.
class RegionBrief {
  const RegionBrief({
    required this.id,
    required this.name,
    required this.generation,
    required this.dexStart,
    required this.dexEnd,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final int generation;
  final int dexStart;
  final int dexEnd;
  final int sortOrder;

  factory RegionBrief.fromSupabaseRow(Map<String, dynamic> row) => RegionBrief(
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        generation: row['generation'] as int? ?? 0,
        dexStart: row['dex_start'] as int? ?? 0,
        dexEnd: row['dex_end'] as int? ?? 0,
        sortOrder: row['sort_order'] as int? ?? 0,
      );
}

/// Um Pokémon da pokédex nacional, lido de `pokedex`.
class PokedexEntry {
  const PokedexEntry({
    required this.nationalDexId,
    required this.name,
    this.regionId,
    this.generation,
    this.types = const [],
    this.spriteUrl,
  });

  final int nationalDexId;
  final String name;
  final String? regionId;
  final int? generation;
  final List<String> types;
  final String? spriteUrl;

  factory PokedexEntry.fromSupabaseRow(Map<String, dynamic> row) => PokedexEntry(
        nationalDexId: row['national_dex_id'] as int,
        name: row['name'] as String? ?? '',
        regionId: row['region_id'] as String?,
        generation: row['generation'] as int?,
        types: (row['types'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        spriteUrl: row['sprite_url'] as String?,
      );
}

/// Abstração fina sobre `regions`/`pokedex` — permite fake em teste.
abstract class PokedexStore {
  Future<List<Map<String, dynamic>>> fetchRegions();
  Future<List<Map<String, dynamic>>> fetchPokedexByRegion(String regionId);
  Future<Map<String, dynamic>?> fetchByNationalDexId(int id);
  Future<List<Map<String, dynamic>>> fetchByNationalDexIds(List<int> ids);
}

class SupabasePokedexStore implements PokedexStore {
  SupabasePokedexStore(this._client);
  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> fetchRegions() async {
    final rows = await _client.from('regions').select().order('sort_order');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPokedexByRegion(String regionId) async {
    final rows = await _client
        .from('pokedex')
        .select()
        .eq('region_id', regionId)
        .order('national_dex_id');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>?> fetchByNationalDexId(int id) async {
    return await _client.from('pokedex').select().eq('national_dex_id', id).maybeSingle();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchByNationalDexIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _client.from('pokedex').select().inFilter('national_dex_id', ids);
    return (rows as List).cast<Map<String, dynamic>>();
  }
}

/// Pokédex e regiões — `pokedex`/`regions` já vêm totalmente populados pela
/// carga inicial (PokéAPI, feita via seed, não neste app). TTL é
/// praticamente infinito: não há cliente de PokéAPI no Flutter hoje, então
/// este repositório só lê a base; se algum dia vier vazio (banco novo sem
/// seed), o certo é rodar a Edge Function `seed-pokedex`, não buscar da UI.
class PokedexRepository {
  PokedexRepository({PokedexStore? store})
      : _store = store ?? SupabasePokedexStore(Supabase.instance.client);

  final PokedexStore _store;

  Future<List<RegionBrief>> fetchRegions() async {
    final rows = await _store.fetchRegions();
    return rows.map(RegionBrief.fromSupabaseRow).toList();
  }

  Future<List<PokedexEntry>> fetchPokedexForRegion(String regionId) async {
    final rows = await _store.fetchPokedexByRegion(regionId);
    return rows.map(PokedexEntry.fromSupabaseRow).toList();
  }

  Future<PokedexEntry?> fetchByNationalDexId(int id) async {
    final row = await _store.fetchByNationalDexId(id);
    return row == null ? null : PokedexEntry.fromSupabaseRow(row);
  }

  /// IDs de região distintos entre os pokémons dados — usado no hero da
  /// Coleção ("{n} regiões").
  Future<Set<String>> regionIdsForNationalDexIds(List<int> ids) async {
    final rows = await _store.fetchByNationalDexIds(ids);
    return rows.map((r) => r['region_id'] as String?).whereType<String>().toSet();
  }
}
