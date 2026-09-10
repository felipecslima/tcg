import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';

import '../../models/card.dart' as domain;
import '../../models/tcg_card.dart';
import '../../repositories/card_repository.dart';
import '../../repositories/set_repository.dart';
import '../../services/camera_image_converter.dart';
import '../../services/card_matcher.dart';
import '../../state/app_shell_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'candidates_sheet.dart';
import 'confirm_screen.dart';

/// Tela 2 do fluxo (README §2 "Escanear") — sub-view da aba Escanear.
///
/// Reaproveita o motor de reconhecimento OCR+set que já funciona
/// (`CardMatcher`, `CameraImageConverter`, o loop de `TextRecognizer` do
/// antigo `ScannerScreen`) — só a casca visual muda pra bater com o design
/// (viewfinder, linha de varredura, pílula da coleção ativa).
///
/// Quando `activeSet` é null ("não sei a coleção — escanear mesmo assim"),
/// o universo de reconhecimento fica em aberto na spec — mas comparar
/// contra as ~23,5k cartas do catálogo inteiro a cada frame é caro demais
/// pra esta rodada (ver HANDOFF, decisão pendente da Fase 1: opção A vs B).
/// Por ora esse caminho mostra a câmera mas não tenta casar nada, com aviso
/// explícito — decisão documentada, não um bug silencioso.
class ScanView extends StatefulWidget {
  const ScanView({super.key, required this.activeSet, required this.onChangeSet});

  final CardSetBrief? activeSet;
  final VoidCallback onChangeSet;

  @override
  State<ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<ScanView> with WidgetsBindingObserver {
  final _cardRepo = CardRepository();
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _matcher = CardMatcher();

  CameraController? _controller;
  CameraImage? _latestFrame;
  Timer? _processingTimer;
  bool _isProcessing = false;
  bool _sheetOpen = false;
  int _initGeneration = 0;
  bool _torchOn = false;
  bool _batchMode = false; // só visual por ora (decisão de produto travada)
  String? _cameraError;

  final _setRepo = CardSetRepository();
  List<TcgCard> _candidates = const [];
  List<CardSetBrief> _allSets = const [];
  bool _loadingCandidates = false;
  String _resolvedKey = '';
  bool _globalMode = false;

  static const _tickInterval = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCandidates();
    _initCamera();
  }

  @override
  void didUpdateWidget(covariant ScanView old) {
    super.didUpdateWidget(old);
    if (old.activeSet?.id != widget.activeSet?.id) _loadCandidates();
  }

  Future<void> _loadCandidates() async {
    final set = widget.activeSet;
    setState(() => _loadingCandidates = true);

    if (set != null) {
      // Modo com set escolhido: busca só as cartas desse set
      _globalMode = false;
      try {
        final cards = await _cardRepo.fetchCardsForSet(set.id);
        if (!mounted) return;
        setState(() {
          _candidates = cards
              .map((c) => TcgCard(
                    id: c.id,
                    setId: c.setId,
                    setName: set.name,
                    name: c.name,
                    localId: c.localId,
                    printedTotal: set.printedTotal,
                    imageBaseUrl: c.imageBaseUrl,
                    dexIds: c.nationalDexIds,
                  ))
              .toList();
        });
      } catch (e) {
        print('Erro ao carregar candidatos do set: $e'); // ignore: avoid_print
        if (mounted) setState(() => _candidates = const []);
      } finally {
        if (mounted) setState(() => _loadingCandidates = false);
      }
      return;
    }

    // Modo universo aberto: carrega todos os sets e suas cartas
    _globalMode = true;
    try {
      final sets = await _setRepo.fetchAllSets();
      if (!mounted) return;
      _allSets = sets;
      final allCards = await _cardRepo.fetchAllCardsBrief();
      if (!mounted) return;
      final setMap = {for (final s in sets) s.id: s};
      setState(() {
        _candidates = allCards
            .map((c) {
              final s = setMap[c.setId];
              return TcgCard(
                id: c.id,
                setId: c.setId,
                setName: s?.name ?? '',
                name: c.name,
                localId: c.localId,
                printedTotal: s?.printedTotal ?? 0,
                imageBaseUrl: c.imageBaseUrl,
                dexIds: c.nationalDexIds,
              );
            })
            .toList();
      });
    } catch (e) {
      print('Erro ao carregar candidatos globais: $e'); // ignore: avoid_print
      if (mounted) setState(() => _candidates = const []);
    } finally {
      if (mounted) setState(() => _loadingCandidates = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed && _tabActive) {
      _initCamera();
    }
  }

  // Aba ativa no AppShell (README §Navegação, tab bar visível em `scan`).
  // O shell usa IndexedStack pra preservar estado das abas — sem observar
  // isso, sair da aba Escanear não desmonta esta tela, e a câmera + o timer
  // de leitura continuariam rodando escondidos atrás da aba visível.
  bool _tabActive = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = context.watch<AppShellController>().tabIndex == AppShellController.scanTabIndex;
    if (active == _tabActive) return;
    _tabActive = active;
    if (active) {
      _initCamera();
    } else {
      _stopCamera();
    }
  }

  void _stopCamera() {
    _initGeneration++;
    _processingTimer?.cancel();
    _processingTimer = null;
    final controller = _controller;
    if (controller == null) return;
    setState(() => _controller = null);
    controller.dispose();
  }

  Future<void> _initCamera() async {
    final gen = _initGeneration;
    try {
      final cameras = await availableCameras();
      if (!mounted || gen != _initGeneration) return;
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'Nenhuma câmera encontrada no dispositivo.');
        return;
      }
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted || gen != _initGeneration) {
        controller.dispose();
        return;
      }
      await controller.setFocusMode(FocusMode.auto);
      if (!mounted || gen != _initGeneration) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await controller.startImageStream((image) => _latestFrame = image);
      _processingTimer = Timer.periodic(_tickInterval, (_) => _processLatestFrame());
    } catch (e) {
      if (mounted && gen == _initGeneration) {
        setState(() => _cameraError = 'Erro ao acessar câmera: $e');
      }
    }
  }

  static String _keyOf(List<TcgCard> cards) => (cards.map((c) => c.id).toList()..sort()).join('|');

  Future<void> _processLatestFrame() async {
    if (_isProcessing || _sheetOpen || _candidates.isEmpty) return;
    final frame = _latestFrame;
    final controller = _controller;
    if (frame == null || controller == null) return;

    _isProcessing = true;
    try {
      final inputImage = CameraImageConverter.toInputImage(frame, controller.description);
      if (inputImage == null) return;
      final recognized = await _textRecognizer.processImage(inputImage);
      final text = recognized.text.trim();
      if (text.isEmpty) return;

      final result = _globalMode
          ? _matcher.matchGlobal(text, _candidates, _allSets)
          : _matcher.match(text, _candidates);
      if (result.choices.isEmpty) {
        _resolvedKey = '';
        return;
      }
      final key = _keyOf(result.choices);
      if (key == _resolvedKey) return;
      _resolvedKey = key;
      _showCandidates(result.choices);
    } catch (_) {
      // frame ruim: ignora e tenta o próximo
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _showCandidates(List<TcgCard> choices) async {
    if (!mounted) return;
    setState(() => _sheetOpen = true);
    final setName = widget.activeSet?.name ?? 'todas as coleções';
    final picked = await showModalBottomSheet<TcgCard>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CandidatesSheet(choices: choices, setLabel: setName),
    );
    if (!mounted) return;
    setState(() => _sheetOpen = false);
    _resolvedKey = ''; // sheet fechou (escolheu ou dispensou): pode perguntar de novo
    if (picked != null) {
      HapticFeedback.mediumImpact();
      _stopCamera();
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => ConfirmScreen(card: _toDomainCard(picked))),
      );
      if (mounted && _tabActive) _initCamera();
    }
  }

  domain.Card _toDomainCard(TcgCard c) => domain.Card(
        id: c.id,
        setId: c.setId,
        setName: c.setName,
        localId: c.localId,
        printedTotal: c.printedTotal,
        name: c.name,
        imageBaseUrl: c.imageBaseUrl,
        nationalDexIds: c.dexIds,
      );

  void _toggleTorch() async {
    final controller = _controller;
    if (controller == null) return;
    final next = !_torchOn;
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      setState(() => _torchOn = next);
    } catch (_) {
      // nem todo device/emulador suporta torch — ignora
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _processingTimer?.cancel();
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.scanChrome,
      child: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const SizedBox(height: 8),
            _buildActiveSetPill(),
            const SizedBox(height: 12),
            Text(
              'Enquadre a carta inteira dentro das marcas',
              style: AppType.body.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Expanded(child: Center(child: _buildViewfinder())),
            _buildHintText(),
            const SizedBox(height: 18),
            _buildControls(),
            const SizedBox(height: 100), // folga da tab bar flutuante
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Expanded(child: Text('Escanear', style: AppType.scanTitle.copyWith(color: Colors.white))),
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
            onPressed: _toggleTorch,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSetPill() {
    final set = widget.activeSet;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                set?.name ?? 'Detecção automática de coleção',
                style: AppType.body.copyWith(color: Colors.white, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: widget.onChangeSet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('trocar', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHintText() {
    String hint;
    if (_loadingCandidates) {
      hint = 'Carregando cartas da coleção…';
    } else if (_sheetOpen) {
      hint = 'Lendo a carta…';
    } else if (_batchMode) {
      hint = 'Modo lote ativo — escaneie várias';
    } else {
      hint = 'Toque para capturar';
    }
    return Text(hint, style: AppType.body.copyWith(color: AppColors.purple300));
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundButton(
          icon: Icons.search,
          size: 52,
          onTap: () => context.read<AppShellController>().switchToTab(3), // aba Busca
        ),
        const SizedBox(width: 34),
        _RoundButton(
          icon: Icons.camera_alt,
          size: 84,
          filled: true,
          onTap: () => HapticFeedback.selectionClick(), // reconhecimento é contínuo — o toque é só feedback tátil
        ),
        const SizedBox(width: 34),
        _RoundButton(
          icon: Icons.layers,
          size: 52,
          highlighted: _batchMode,
          onTap: () => setState(() => _batchMode = !_batchMode), // toggle visual (backlog: lote de verdade)
        ),
      ],
    );
  }

  Widget _buildViewfinder() {
    return Container(
      width: 274,
      height: 374,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 250,
            height: 350,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildCameraPreview(),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              size: const Size(250, 350),
              painter: _ViewfinderCornersPainter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraError != null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_cameraError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator()));
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.previewSize?.height ?? 250,
        height: controller.value.previewSize?.width ?? 350,
        child: CameraPreview(controller),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.size,
    required this.onTap,
    this.filled = false,
    this.highlighted = false,
  });
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final bool filled;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final bg = filled
        ? AppColors.primary
        : highlighted
            ? AppColors.purple600.withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.1);
    return Material(
      color: bg,
      shape: CircleBorder(side: filled ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white, size: filled ? 32 : 22),
        ),
      ),
    );
  }
}

class _ViewfinderCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.purple400
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 40.0;
    final w = size.width, h = size.height;
    void corner(Offset a, Offset b, Offset c) {
      canvas.drawLine(a, b, paint);
      canvas.drawLine(b, c, paint);
    }

    corner(const Offset(0, l), Offset.zero, const Offset(l, 0));
    corner(Offset(w - l, 0), Offset(w, 0), Offset(w, l));
    corner(Offset(0, h - l), Offset(0, h), Offset(l, h));
    corner(Offset(w - l, h), Offset(w, h), Offset(w, h - l));
  }

  @override
  bool shouldRepaint(covariant _ViewfinderCornersPainter old) => false;
}
