import 'dart:async';

import 'package:flutter/material.dart' hide Card;

import '../models/card.dart';
import '../repositories/card_repository.dart';
import '../repositories/collection_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/loaders/loaders.dart';
import '../widgets/app_widgets.dart';
import 'card_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _cardRepo = CardRepository();
  final _collectionRepo = CollectionRepository();

  Timer? _debounce;
  List<Card>? _results;
  Map<String, int> _owned = {};
  bool _loading = false;
  String? _error;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    setState(() => _query = value.trim());
    if (value.trim().length < 2) {
      setState(() {
        _results = null;
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value.trim()));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _cardRepo.searchCards(query);
      if (!mounted || _query != query) return;
      final cardIds = results.map((c) => c.id).toList();
      final owned = await _collectionRepo.ownedQuantityByCardId(cardIds);
      if (!mounted) return;
      setState(() {
        _results = results;
        _owned = owned;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _onChipTap(String label) {
    _controller.text = label;
    _onQueryChanged(label);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppTheme.screenPadding.copyWith(bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Busca', style: AppType.screenTitle),
          const SizedBox(height: 16),
          _SearchField(
            controller: _controller,
            onChanged: _onQueryChanged,
            onClear: () {
              _controller.clear();
              _onQueryChanged('');
            },
          ),
          const SizedBox(height: 12),
          if (_query.isEmpty) ...[
            _ChipsRow(onTap: _onChipTap),
            const SizedBox(height: 20),
            Text('SUGESTÕES PARA VOCÊ', style: AppType.sectionLabel),
          ] else if (_results != null)
            Text(
              '${_results!.length} RESULTADO${_results!.length != 1 ? 'S' : ''}',
              style: AppType.sectionLabel,
            ),
          const SizedBox(height: 10),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: MedalhaoLoader());
    }
    if (_error != null) {
      return Center(
        child: Text('Erro na busca: $_error',
            style: AppType.body.copyWith(color: AppColors.text3)),
      );
    }
    if (_results != null && _results!.isEmpty) {
      return _NoResults(query: _query);
    }
    if (_results == null) return const SizedBox.shrink();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: _results!.length,
      itemBuilder: (context, i) {
        final card = _results![i];
        final qty = _owned[card.id] ?? 0;
        return _SearchResultRow(
          card: card,
          ownedQty: qty,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CardDetailScreen(card: card, origin: 'Busca'),
            ),
          ),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppType.body,
      decoration: InputDecoration(
        hintText: 'Nome da carta, set ou número…',
        prefixIcon: const Icon(Icons.search, color: AppColors.text4),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.text4),
                onPressed: onClear,
              )
            : null,
      ),
    );
  }
}

class _ChipsRow extends StatelessWidget {
  const _ChipsRow({required this.onTap});
  final ValueChanged<String> onTap;

  static const _suggestions = ['Pikachu', 'Charizard', 'Mewtwo', 'Eevee'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in _suggestions)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppChip(label: s, onTap: () => onTap(s)),
            ),
        ],
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.card,
    required this.ownedQty,
    required this.onTap,
  });

  final Card card;
  final int ownedQty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.listRow),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.listRow),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                card.thumbnailUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.miniArt),
                        child: Image.network(
                          card.thumbnailUrl!,
                          width: 44,
                          height: 61,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const ArtPlaceholder(width: 44, height: 61, radius: AppRadii.miniArt),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.name,
                          style: AppType.listTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        '${card.setName} · ${card.localId}',
                        style: AppType.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ownedQty > 0 ? AppColors.green : AppColors.border1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 48, color: AppColors.text4),
          const SizedBox(height: 12),
          Text(
            'Nenhum resultado para "$query"',
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: AppColors.text3),
          ),
          const SizedBox(height: 4),
          Text(
            'Tente um nome ou número diferente.',
            style: AppType.caption,
          ),
        ],
      ),
    );
  }
}
