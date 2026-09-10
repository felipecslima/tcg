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

/// Fallback estático das 9 regiões — dados que nunca mudam, evitam depender
/// da tabela `regions` estar populada via seed.
const kRegionsFallback = [
  RegionBrief(id: 'kanto', name: 'Kanto', generation: 1, dexStart: 1, dexEnd: 151, sortOrder: 1),
  RegionBrief(id: 'johto', name: 'Johto', generation: 2, dexStart: 152, dexEnd: 251, sortOrder: 2),
  RegionBrief(id: 'hoenn', name: 'Hoenn', generation: 3, dexStart: 252, dexEnd: 386, sortOrder: 3),
  RegionBrief(id: 'sinnoh', name: 'Sinnoh', generation: 4, dexStart: 387, dexEnd: 493, sortOrder: 4),
  RegionBrief(id: 'unova', name: 'Unova', generation: 5, dexStart: 494, dexEnd: 649, sortOrder: 5),
  RegionBrief(id: 'kalos', name: 'Kalos', generation: 6, dexStart: 650, dexEnd: 721, sortOrder: 6),
  RegionBrief(id: 'alola', name: 'Alola', generation: 7, dexStart: 722, dexEnd: 809, sortOrder: 7),
  RegionBrief(id: 'galar', name: 'Galar', generation: 8, dexStart: 810, dexEnd: 905, sortOrder: 8),
  RegionBrief(id: 'paldea', name: 'Paldea', generation: 9, dexStart: 906, dexEnd: 1025, sortOrder: 9),
];

/// Retorna a região à qual um national dex id pertence, ou null.
RegionBrief? regionForDex(int dexId) {
  for (final r in kRegionsFallback) {
    if (dexId >= r.dexStart && dexId <= r.dexEnd) return r;
  }
  return null;
}

/// Pokédex e regiões — `pokedex`/`regions` já vêm totalmente populados pela
/// carga inicial (PokéAPI, feita via seed, não neste app). TTL é
/// praticamente infinito: não há cliente de PokéAPI no Flutter hoje, então
/// este repositório só lê a base; se algum dia vier vazio (banco novo sem
/// seed), usa o fallback estático em Dart.
class PokedexRepository {
  PokedexRepository({PokedexStore? store})
      : _store = store ?? SupabasePokedexStore(Supabase.instance.client);

  final PokedexStore _store;

  Future<List<RegionBrief>> fetchRegions() async {
    final rows = await _store.fetchRegions();
    if (rows.isEmpty) return List.unmodifiable(kRegionsFallback);
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
