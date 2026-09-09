import 'package:flutter/material.dart';

import '../models/tcg_card.dart';
import '../services/tcgdex_api_service.dart';
import 'scanner_screen.dart';

/// Primeira tela do fluxo: escolher idioma + set antes de escanear.
/// Isso é o pré-filtro que discutimos no plano — restringe o universo de
/// matching a um set só, em vez de comparar contra o catálogo inteiro.
class SetSelectionScreen extends StatefulWidget {
  const SetSelectionScreen({super.key});

  @override
  State<SetSelectionScreen> createState() => _SetSelectionScreenState();
}

class _SetSelectionScreenState extends State<SetSelectionScreen> {
  final _api = TcgdexApiService();

  String _language = 'en';
  List<TcgSetBrief>? _sets;
  String? _error;
  bool _loadingCards = false;

  @override
  void initState() {
    super.initState();
    _loadSets();
  }

  Future<void> _loadSets() async {
    setState(() {
      _sets = null;
      _error = null;
    });
    try {
      final sets = await _api.fetchAllSets(language: _language);
      if (!mounted) return;
      setState(() => _sets = sets);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Não consegui carregar os sets: $e');
    }
  }

  Future<void> _selectSet(TcgSetBrief set) async {
    setState(() => _loadingCards = true);
    try {
      final cards = await _api.fetchCardsForSet(set.id, language: _language);
      if (!mounted) return;
      if (cards.isEmpty) {
        setState(() => _loadingCards = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esse set não retornou nenhuma carta.')),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ScannerScreen(
            candidates: cards,
            setName: set.name,
            setId: set.id,
            language: _language,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar cartas do set: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingCards = false);
    }
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PokeCardex Scanner — MVP')),
      body: Column(
        children: [
          _buildLanguagePicker(),
          const Divider(height: 1),
          Expanded(child: _buildSetList()),
        ],
      ),
    );
  }

  Widget _buildLanguagePicker() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Text('Idioma das cartas:'),
          const SizedBox(width: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'en', label: Text('Inglês')),
              ButtonSegment(value: 'pt', label: Text('Português')),
            ],
            selected: {_language},
            onSelectionChanged: (selection) {
              setState(() => _language = selection.first);
              _loadSets();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSetList() {
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_sets == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadingCards) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Carregando cartas do set...'),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _sets!.length,
      itemBuilder: (context, index) {
        final set = _sets![index];
        return ListTile(
          leading: set.logoUrl != null
              ? Image.network(set.logoUrl!, width: 48, errorBuilder: (_, __, ___) => const Icon(Icons.style))
              : const Icon(Icons.style),
          title: Text(set.name),
          subtitle: Text('${set.cardCount} cartas'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _selectSet(set),
        );
      },
    );
  }
}
