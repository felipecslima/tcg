import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/scan_session_models.dart';
import '../models/tcg_card.dart';
import '../services/camera_image_converter.dart';
import '../services/card_matcher.dart';
import 'card_detail_screen.dart';
import 'review_screen.dart';

/// Tela de scan em "modo rajada": câmera fica ligada o tempo todo, sem
/// botão de tirar foto. A cada ~600ms processamos o frame mais recente,
/// tentamos reconhecer texto e casar contra as cartas do set carregado.
///
/// Duas regras evitam ruído:
/// - Um match só conta quando a carta reconhecida MUDA em relação à
///   última (senão segurar a mesma carta na frente da câmera por 3s conta
///   3x). Pra escanear 2 cópias da mesma carta, é só tirar e recolocar na
///   frente da câmera.
/// - Pendências seguem a mesma lógica: só entra uma pendência nova se o
///   texto reconhecido mudou desde a última tentativa.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({
    super.key,
    required this.candidates,
    required this.setName,
    required this.setId,
    required this.language,
  });

  final List<TcgCard> candidates;
  final String setName;
  final String setId;
  final String language;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _matcher = CardMatcher();
  late final ScanSession _session;

  CameraImage? _latestFrame;
  Timer? _processingTimer;
  bool _isProcessing = false;
  bool _isPaused = false;
  bool _navigating = false; // na tela de detalhe da carta — não processa frames
  String? _lastRecognizedPreview;
  String? _cameraError;

  /// Nada entra sem toque. Enquanto tem carta(s) aqui, o scan PARA e espera
  /// o usuário confirmar (1) ou escolher (2–3).
  List<TcgCard> _choices = const [];

  /// Conjunto de cartas que o usuário já resolveu (confirmou uma ou dispensou)
  /// — não pergunta de novo enquanto a mesma carta continua na frente.
  String _resolvedKey = '';

  static const _tickInterval = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = ScanSession(setId: widget.setId, setName: widget.setName, language: widget.language);
    _initCamera();
  }

  // O iOS (e o Android) suspendem a captura da câmera quando o app sai de
  // foreground — a tela apaga, você troca de app pra pegar a próxima carta,
  // etc. Sem isso, ao voltar pro app o stream fica morto e o scanner para
  // de reconhecer qualquer coisa, mesmo a UI parecendo normal.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _processingTimer?.cancel();
      _processingTimer = null;
      setState(() => _controller = null);
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
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
        // Android entrega YUV420 planar (3 planos); pedir yuv420 no iOS na
        // verdade retorna YUV420 bi-planar (2 planos), que CameraImageConverter
        // não sabe converter — por isso forçamos BGRA8888 (single-plane) lá.
        imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      await controller.setFocusMode(FocusMode.auto);
      if (!mounted) return;
      setState(() => _controller = controller);
      await controller.startImageStream((image) => _latestFrame = image);
      _processingTimer = Timer.periodic(_tickInterval, (_) => _processLatestFrame());
    } catch (e) {
      if (mounted) {
        setState(() => _cameraError = 'Erro ao acessar câmera: $e');
      }
    }
  }

  static String _keyOf(List<TcgCard> cards) =>
      (cards.map((c) => c.id).toList()..sort()).join('|');

  Future<void> _processLatestFrame() async {
    // Enquanto tem carta pra confirmar/escolher ou a tela de detalhe está
    // aberta, o scan fica PARADO.
    if (_isPaused || _isProcessing || _navigating || _choices.isNotEmpty) return;
    final frame = _latestFrame;
    final controller = _controller;
    if (frame == null || controller == null) return;

    _isProcessing = true;
    try {
      final inputImage = CameraImageConverter.toInputImage(frame, controller.description);
      if (inputImage == null) {
        developer.log('Falha ao converter frame', name: 'pokecardex.scanner');
        return;
      }

      final recognized = await _textRecognizer.processImage(inputImage);
      final text = recognized.text.trim();
      if (text.isEmpty) return;

      if (mounted) {
        setState(() => _lastRecognizedPreview = text.split('\n').take(2).join(' · '));
      }

      final result = _matcher.match(text, widget.candidates);
      if (result.choices.isEmpty) {
        _resolvedKey = ''; // não tem carta na frente → esquece o que foi resolvido
        return;
      }
      final key = _keyOf(result.choices);
      if (key == _resolvedKey) return; // mesma carta ainda na frente, já resolvida

      developer.log('Pergunta: ${result.choices.map((c) => c.localId).join("/")} '
          '(score ${result.score.toStringAsFixed(2)})', name: 'pokecardex.scanner');
      _resolvedKey = '';
      if (mounted) setState(() => _choices = result.choices);
    } catch (e) {
      developer.log('Erro processando frame: $e', name: 'pokecardex.scanner', error: e);
    } finally {
      _isProcessing = false;
    }
  }

  void _confirm(TcgCard card) {
    _resolvedKey = _keyOf(_choices);
    HapticFeedback.mediumImpact();
    setState(() {
      _session.addMatch(card);
      _choices = const [];
    });
    _openDetail(card);
  }

  Future<void> _openDetail(TcgCard card) async {
    _navigating = true;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CardDetailScreen(card: card, language: widget.language),
      ),
    );
    if (mounted) _navigating = false;
  }

  void _dismissChoices() {
    _resolvedKey = _keyOf(_choices); // não conta nada, não repergunta o mesmo
    setState(() => _choices = const []);
  }

  void _togglePause() => setState(() => _isPaused = !_isPaused);

  void _retryCameraInit() {
    setState(() => _cameraError = null);
    _initCamera();
  }

  Future<void> _finishSession() async {
    _processingTimer?.cancel();
    final controller = _controller;
    if (controller != null && controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReviewScreen(session: _session)),
    );
    // Voltou da revisão (botão "voltar") em vez de fechar a sessão — retoma
    // o scan de onde parou.
    if (!mounted) return;
    final resumedController = _controller;
    if (resumedController != null &&
        resumedController.value.isInitialized &&
        !resumedController.value.isStreamingImages) {
      await resumedController.startImageStream((image) => _latestFrame = image);
      _processingTimer = Timer.periodic(_tickInterval, (_) => _processLatestFrame());
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Escaneando: ${widget.setName}'),
        actions: [
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            onPressed: _togglePause,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildCameraPreview()),
          _buildSessionSummary(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _finishSession,
        icon: const Icon(Icons.check),
        label: Text('Revisar (${_session.totalScannedCount})'),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraError != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.red, size: 64),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _cameraError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _retryCameraInit,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: 1 / controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
        ),
        if (_lastRecognizedPreview != null)
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Lendo: $_lastRecognizedPreview',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        if (_choices.isNotEmpty) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismissChoices,
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 56),
                child: Text(
                  _choices.length == 1
                      ? '⏸  Parado — confirme a carta'
                      : '⏸  Parado — escolha a carta',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _CardPrompt(
              choices: _choices,
              onPick: _confirm,
              onDismiss: _dismissChoices,
            ),
          ),
        ],
        if (_isPaused)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: const Text('Pausado', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
          ),
      ],
    );
  }

  Widget _buildSessionSummary() {
    return Container(
      color: const Color(0xFF111111),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        '${_session.scannedEntries.length} cartas únicas · ${_session.totalScannedCount} no total',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

/// Card de confirmação / escolha. Nada entra na sessão sem passar por aqui.
///   1 carta  → miniatura + nome/número + [Confirmar] / [Não é]
///   2–3      → grade de miniaturas pra escolher
class _CardPrompt extends StatelessWidget {
  const _CardPrompt({
    required this.choices,
    required this.onPick,
    required this.onDismiss,
  });

  final List<TcgCard> choices;
  final void Function(TcgCard) onPick;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final box = BoxDecoration(
      color: Colors.black.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(12),
    );
    if (choices.length == 1) {
      final c = choices.first;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: box,
        child: Row(
          children: [
            if (c.thumbnailUrl != null)
              Image.network(c.thumbnailUrl!, height: 72,
                  errorBuilder: (_, __, ___) => const SizedBox(height: 72, width: 52)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('#${c.localId}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: () => onPick(c),
                        child: const Text('Confirmar'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: onDismiss,
                        style: TextButton.styleFrom(foregroundColor: Colors.white70),
                        child: const Text('Não é'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final allSameName = choices.every((c) => c.name == choices.first.name);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: box,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  allSameName ? '${choices.first.name} — qual versão?' : 'Qual carta?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: const Icon(Icons.close, color: Colors.white54, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final c in choices)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: () => onPick(c),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (c.thumbnailUrl != null)
                            Image.network(c.thumbnailUrl!, height: 68,
                                errorBuilder: (_, __, ___) => const SizedBox(height: 68, width: 49)),
                          const SizedBox(height: 2),
                          if (!allSameName)
                            Text(c.name,
                                style: const TextStyle(fontSize: 11),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('#${c.localId}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
