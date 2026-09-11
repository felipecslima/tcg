import 'package:flutter/material.dart' hide Card;
import 'package:provider/provider.dart';

import '../../repositories/collection_repository.dart';
import '../../state/app_shell_controller.dart';
import '../../state/batch_session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/loaders/loaders.dart';
import '../../widgets/primary_button.dart';

const _finishes = ['normal', 'reverse', 'holo'];
String _finishLabel(String f) => switch (f) {
      'reverse' => 'Reverse',
      'holo' => 'Holo',
      _ => 'Normal',
    };

class BatchReviewScreen extends StatefulWidget {
  const BatchReviewScreen({super.key});

  @override
  State<BatchReviewScreen> createState() => _BatchReviewScreenState();
}

class _BatchReviewScreenState extends State<BatchReviewScreen> {
  final _collectionRepo = CollectionRepository();

  List<UserCollection>? _collections;
  String? _destinationId;
  String _defaultFinish = 'normal';
  bool _saving = false;
  String? _error;
  int _savedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    try {
      final collections = await _collectionRepo.fetchUserCollections();
      if (!mounted) return;
      setState(() {
        _collections = collections;
        _destinationId = collections
            .firstWhere((c) => c.kind == 'default', orElse: () => collections.first)
            .id;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Erro ao carregar coleções: $e');
    }
  }

  Future<void> _saveAll() async {
    final session = context.read<BatchSession>();
    final destination = _destinationId;
    if (destination == null || _saving || session.isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
      _savedCount = 0;
    });

    final entries = List.of(session.entries);
    try {
      for (final entry in entries) {
        await _collectionRepo.addCardToCollection(
          collectionId: destination,
          cardId: entry.card.id,
          finish: entry.finish,
          quantity: entry.quantity,
          language: entry.language,
        );
        if (!mounted) return;
        setState(() => _savedCount++);
      }
      if (!mounted) return;

      final total = entries.fold(0, (sum, e) => sum + e.quantity);
      final destName = _collections!.firstWhere((c) => c.id == destination).name;
      session.clear();
      final shell = context.read<AppShellController>();
      Navigator.of(context, rootNavigator: true).pop();
      shell.goToCollectionWithToast('$total ${total == 1 ? 'carta adicionada' : 'cartas adicionadas'} à $destName');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Erro ao salvar ($_savedCount/${entries.length} salvas): $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<BatchSession>();
    final collections = _collections;
    final totalQty = session.entries.fold(0, (sum, e) => sum + e.quantity);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context, rootNavigator: true).pop()),
        title: Text('Revisar ${session.distinctCount} ${session.distinctCount == 1 ? 'carta' : 'cartas'}'),
      ),
      body: collections == null
          ? const Center(child: PulinhoLoader())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                    children: [
                      Text('GUARDAR EM', style: AppType.sectionLabel),
                      const SizedBox(height: 8),
                      _CollectionDropdown(
                        collections: collections,
                        value: _destinationId,
                        onChanged: (v) => setState(() => _destinationId = v),
                      ),
                      const SizedBox(height: 20),
                      Text('ACABAMENTO PADRÃO', style: AppType.sectionLabel),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final f in _finishes)
                            AppChip(
                              label: _finishLabel(f),
                              selected: _defaultFinish == f,
                              onTap: () {
                                setState(() => _defaultFinish = f);
                                for (var i = 0; i < session.entries.length; i++) {
                                  session.updateEntry(i, finish: f);
                                }
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('CARTAS', style: AppType.sectionLabel),
                      const SizedBox(height: 8),
                      for (var i = 0; i < session.entries.length; i++)
                        _buildEntryRow(session, i),
                    ],
                  ),
                ),
                _buildFooter(totalQty),
              ],
            ),
    );
  }

  Widget _buildEntryRow(BatchSession session, int index) {
    final entry = session.entries[index];
    return Dismissible(
      key: ValueKey('${entry.card.id}-${entry.finish}-$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.listRow),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.red),
      ),
      onDismissed: (_) => session.removeAt(index),
      child: GestureDetector(
        onTap: () => _showEntryEditor(session, index),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.listRow),
            border: Border.all(color: AppColors.border1),
          ),
          child: Row(
            children: [
              entry.card.thumbnailUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.miniArt),
                      child: Image.network(entry.card.thumbnailUrl!, width: 44, height: 62, fit: BoxFit.cover),
                    )
                  : const ArtPlaceholder(width: 44, height: 62, radius: AppRadii.miniArt),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.card.name, style: AppType.listTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.card.setName} · #${entry.card.localId}',
                      style: AppType.caption,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_finishLabel(entry.finish), style: AppType.caption),
                  const SizedBox(height: 2),
                  Text('×${entry.quantity}', style: AppType.mono.copyWith(color: AppColors.text1)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEntryEditor(BatchSession session, int index) {
    final entry = session.entries[index];
    var tempFinish = entry.finish;
    var tempQty = entry.quantity;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
            ),
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.border2, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(entry.card.name, style: AppType.listTitleLg),
                const SizedBox(height: 16),
                Text('ACABAMENTO', style: AppType.sectionLabel),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final f in _finishes)
                      AppChip(
                        label: _finishLabel(f),
                        selected: tempFinish == f,
                        onTap: () => setSheetState(() => tempFinish = f),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('QUANTIDADE', style: AppType.sectionLabel),
                const SizedBox(height: 8),
                QtyStepper(value: tempQty, onChanged: (v) => setSheetState(() => tempQty = v)),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Aplicar',
                  onPressed: () {
                    session.updateEntry(index, finish: tempFinish, quantity: tempQty);
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(int totalQty) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Text(_error!, style: AppType.bodySm.copyWith(color: AppColors.red)),
            const SizedBox(height: 8),
          ],
          if (_saving)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: BarraLoader(
                progress: context.read<BatchSession>().distinctCount > 0
                    ? _savedCount / context.read<BatchSession>().distinctCount
                    : 0,
              ),
            ),
          PrimaryButton(
            label: 'Salvar todas ($totalQty)',
            loading: _saving,
            onPressed: _destinationId == null || totalQty == 0 ? null : _saveAll,
          ),
        ],
      ),
    );
  }
}

class _CollectionDropdown extends StatelessWidget {
  const _CollectionDropdown({required this.collections, required this.value, required this.onChanged});

  final List<UserCollection> collections;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.listRow),
        border: Border.all(color: AppColors.border2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.text4),
          style: AppType.body,
          items: [
            for (final c in collections)
              DropdownMenuItem(value: c.id, child: Text(c.name)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
