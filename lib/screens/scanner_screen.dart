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
  String? _lastMatchedCardId;
  String? _lastPendingText;
  String? _lastRecognizedPreview;
  String? _cameraError;

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

  Future<void> _processLatestFrame() async {
    if (_isPaused || _isProcessing) return;
    final frame = _latestFrame;
    final controller = _controller;
    if (frame == null || controller == null) return;

    _isProcessing = true;
    try {
      final inputImage = CameraImageConverter.toInputImage(frame, controller.description);
      if (inputImage == null) {
        developer.log('Failed to convert camera image to InputImage', name: 'pokecardex.scanner');
        return;
      }

      final recognized = await _textRecognizer.processImage(inputImage);
      final text = recognized.text.trim();
      if (text.isEmpty) return;

      setState(() => _lastRecognizedPreview = text.split('\n').take(2).join(' · '));

      final result = _matcher.match(text, widget.candidates);
      if (result.isConfident && result.card != null) {
        developer.log('Match found: ${result.card!.name} (score: ${result.score})', name: 'pokecardex.scanner');
        _handleMatch(result.card!);
      } else {
        developer.log('No confident match for text: $text (best score: ${result.score})', name: 'pokecardex.scanner');
        _handlePending(text);
      }
    } catch (e) {
      developer.log('Error processing frame: $e', name: 'pokecardex.scanner', error: e);
    } finally {
      _isProcessing = false;
    }
  }

  void _handleMatch(TcgCard card) {
    if (card.id == _lastMatchedCardId) return; // mesma carta ainda em frame
    _lastMatchedCardId = card.id;
    _lastPendingText = null;
    HapticFeedback.mediumImpact();
    setState(() => _session.addMatch(card));
  }

  void _handlePending(String text) {
    // Normaliza grosseiramente pra não duplicar pendência do mesmo ruído.
    final key = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (key == _lastPendingText) return;
    _lastPendingText = key;
    _lastMatchedCardId = null;
    setState(() => _session.addPending(text));
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_session.scannedEntries.length} cartas únicas · ${_session.totalScannedCount} no total',
            style: const TextStyle(color: Colors.white),
          ),
          Text(
            '${_session.pending.length} pendentes',
            style: TextStyle(color: _session.pending.isEmpty ? Colors.white54 : Colors.amber),
          ),
        ],
      ),
    );
  }
}
