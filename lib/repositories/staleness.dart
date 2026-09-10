/// `updatedAt` mais velho que `ttl` (ou nulo/ausente) conta como vencido —
/// dispara refetch na API, mas nunca impede servir o dado (offline-first).
bool isStale(DateTime? updatedAt, Duration ttl) {
  if (updatedAt == null) return true;
  return DateTime.now().toUtc().difference(updatedAt.toUtc()) > ttl;
}

/// Mais recente `updated_at` entre linhas de uma consulta — usado como
/// proxy de "a última sincronização deste recorte de dados".
DateTime? freshestUpdatedAt(Iterable<Map<String, dynamic>> rows, {String key = 'updated_at'}) {
  DateTime? freshest;
  for (final r in rows) {
    final v = DateTime.tryParse(r[key] as String? ?? '');
    if (v != null && (freshest == null || v.isAfter(freshest))) freshest = v;
  }
  return freshest;
}
