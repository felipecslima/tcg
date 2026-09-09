import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/scan_session_models.dart';

/// Tela de revisão no fim da sessão de scan: mostra o que foi reconhecido
/// e o que ficou pendente. Nesse MVP, "confirmar" só salva um JSON local
/// (não tem Supabase ainda — isso é proposital, ver plano) pra você já
/// conseguir inspecionar o resultado de uma sessão de scan real.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.session});

  final ScanSession session;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  String? _savedPath;

  Future<void> _saveToLocalJson() async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'scan_${widget.session.setId}_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${dir.path}/$fileName');

    final data = {
      'setId': widget.session.setId,
      'setName': widget.session.setName,
      'language': widget.session.language,
      'scannedAt': DateTime.now().toIso8601String(),
      'scanned': widget.session.scannedEntries
          .map((e) => {
                'cardId': e.card.id,
                'name': e.card.name,
                'localId': e.card.localId,
                'count': e.count,
              })
          .toList(),
      'pending': widget.session.pending
          .map((p) => {
                'rawText': p.rawRecognizedText,
                'scannedAt': p.scannedAt.toIso8601String(),
              })
          .toList(),
    };

    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    setState(() => _savedPath = file.path);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Scaffold(
      appBar: AppBar(title: Text('Revisão — ${session.setName}')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${session.scannedEntries.length} cartas reconhecidas '
              '(${session.totalScannedCount} no total) · ${session.pending.length} pendentes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (session.scannedEntries.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Reconhecidas', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...session.scannedEntries.map((entry) => ListTile(
                  leading: entry.card.thumbnailUrl != null
                      ? Image.network(entry.card.thumbnailUrl!, width: 40,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported))
                      : const Icon(Icons.image_not_supported),
                  title: Text(entry.card.name),
                  subtitle: Text('#${entry.card.localId}'),
                  trailing: Text('x${entry.count}'),
                )),
          ],
          if (session.pending.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Pendentes (resolver manualmente depois)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
            ),
            ...session.pending.map((p) => ListTile(
                  leading: const Icon(Icons.help_outline, color: Colors.amber),
                  title: Text(
                    p.rawRecognizedText.split('\n').take(2).join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
          ],
          if (_savedPath != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Salvo em: $_savedPath', style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveToLocalJson,
        icon: const Icon(Icons.save),
        label: const Text('Salvar sessão (JSON local)'),
      ),
    );
  }
}
