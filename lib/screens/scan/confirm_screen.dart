import 'package:flutter/material.dart' hide Card;
import 'package:provider/provider.dart';

import '../../models/card.dart';
import '../../repositories/card_repository.dart';
import '../../repositories/collection_repository.dart';
import '../../repositories/price_repository.dart';
import '../../services/fx_service.dart';
import '../../state/app_shell_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/loaders/loaders.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/primary_button.dart';

const _finishes = ['normal', 'reverse', 'holo'];
String _finishLabel(String f) => switch (f) {
      'reverse' => 'Reverse',
      'holo' => 'Holo',
      _ => 'Normal',
    };

/// Tela 4 do fluxo (README §4 "Confirmar") — push real, sem tab bar.
/// Estado de conservação NÃO é pedido aqui (decisão de produto travada,
/// grava com o default do banco, `'NM'`).
class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({super.key, required this.card, this.language = 'pt'});

  final Card card;
  final String language;

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  final _cardRepo = CardRepository();
  final _collectionRepo = CollectionRepository();
  final _priceRepo = PriceRepository();

  Card? _detail; // carta com rarity/attacks, se conseguir buscar
  List<UserCollection>? _collections;
  String? _destinationId;
  String _finish = 'normal';
  int _qty = 1;
  double? _priceBrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      widget.card.isBrief
          ? _cardRepo.fetchCardDetail(widget.card.id).catchError((_) => widget.card)
          : Future.value(widget.card),
      _collectionRepo.fetchUserCollections(),
      _priceRepo.fetchLatestPrice(widget.card.id).catchError((_) => null),
    ]);
    if (!mounted) return;
    final collections = results[1] as List<UserCollection>;
    setState(() {
      _detail = results[0] as Card;
      _collections = collections;
      _destinationId = collections
          .firstWhere((c) => c.kind == 'default', orElse: () => collections.first)
          .id;
      _priceBrl = (results[2] as dynamic)?.brl as double?;
    });
  }

  Future<void> _save() async {
    final destination = _destinationId;
    if (destination == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final sw = Stopwatch()..start();
      await _collectionRepo.addCardToCollection(
        collectionId: destination,
        cardId: widget.card.id,
        finish: _finish,
        quantity: _qty,
        language: widget.language,
      );
      final remaining = 1100 - sw.elapsedMilliseconds;
      if (remaining > 0) {
        await Future.delayed(Duration(milliseconds: remaining));
      }
      if (!mounted) return;
      final destName =
          _collections!.firstWhere((c) => c.id == destination).name;
      final shellController = context.read<AppShellController>();
      Navigator.of(context, rootNavigator: true).pop();
      shellController.goToCollectionWithToast('${widget.card.name} → $destName');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Não consegui salvar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _detail ?? widget.card;
    final collections = _collections;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context, rootNavigator: true).pop()),
        title: const Text('Confirmar'),
      ),
      body: collections == null
          ? const Center(child: PulinhoLoader())
          : ListView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
              children: [
                _Header(card: card, priceBrl: _priceBrl),
                const SizedBox(height: 28),
                Text('GUARDAR EM', style: AppType.sectionLabel),
                const SizedBox(height: 8),
                RadioGroup<String>(
                  groupValue: _destinationId,
                  onChanged: (v) => setState(() => _destinationId = v),
                  child: Column(
                    children: [
                      for (final c in collections)
                        RadioListTile<String>(
                          value: c.id,
                          title: Text(c.name, style: AppType.body),
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('ACABAMENTO', style: AppType.sectionLabel),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final f in _finishes)
                      AppChip(
                        label: _finishLabel(f),
                        selected: _finish == f,
                        onTap: () => setState(() => _finish = f),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('QUANTAS CÓPIAS', style: AppType.sectionLabel),
                const SizedBox(height: 8),
                QtyStepper(value: _qty, onChanged: (v) => setState(() => _qty = v)),
                const SizedBox(height: 28),
                if (_error != null) ...[
                  Text(_error!, style: AppType.body.copyWith(color: AppColors.red)),
                  const SizedBox(height: 12),
                ],
                PrimaryButton(
                  label: 'Salvar na coleção',
                  loading: _saving,
                  loadingLabel: 'Salvando…',
                  onPressed: _destinationId == null ? null : _save,
                ),
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.card, this.priceBrl});
  final Card card;
  final double? priceBrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        card.thumbnailUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.gridArt),
                child: Image.network(card.thumbnailUrl!, width: 126, height: 176, fit: BoxFit.cover),
              )
            : const ArtPlaceholder(width: 126, height: 176),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(card.name, style: AppType.cardTitle),
              const SizedBox(height: 4),
              Text('${card.setName} · #${card.localId}',
                  style: AppType.body.copyWith(color: AppColors.text3)),
              const SizedBox(height: 8),
              if (card.rarity != null) RarityPill(card.rarity!),
              const SizedBox(height: 10),
              Text(
                priceBrl != null ? 'valor estimado ${formatBrl(priceBrl!)}' : 'valor estimado —',
                style: AppType.mono.copyWith(fontSize: 12, color: AppColors.text4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
