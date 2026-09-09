import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Converte um frame cru da câmera (`CameraImage`) pro formato que o ML Kit
/// espera (`InputImage`). Essa é, de longe, a parte mais delicada do
/// scanner — Android e iOS entregam o frame em formatos diferentes, e um
/// erro aqui não quebra com uma exceção clara, só faz o reconhecimento
/// falhar silenciosamente (nenhum texto sai). Se o scanner não reconhecer
/// nada mesmo com boa iluminação, é o primeiro lugar pra debugar — vale
/// logar `image.format.group` e `image.planes.length` no dispositivo real.
///
/// Baseado no padrão usado pelos exemplos oficiais do pacote
/// google_mlkit_text_recognition + camera.
class CameraImageConverter {
  static InputImage? toInputImage(
    CameraImage image,
    CameraDescription cameraDescription,
  ) {
    final rotation = _rotationFromSensorOrientation(cameraDescription.sensorOrientation);
    if (rotation == null) {
      developer.log(
        'CameraImageConverter: invalid sensor orientation ${cameraDescription.sensorOrientation}',
        name: 'pokecardex.camera',
      );
      return null;
    }

    try {
      if (Platform.isIOS) {
        return _fromIosBgra(image, rotation);
      }
      if (Platform.isAndroid) {
        return _fromAndroidYuv420(image, rotation);
      }
    } catch (e) {
      developer.log(
        'CameraImageConverter error: $e. Image format: ${image.format.group}, planes: ${image.planes.length}',
        name: 'pokecardex.camera',
        error: e,
      );
    }
    return null;
  }

  static InputImage? _fromIosBgra(CameraImage image, InputImageRotation rotation) {
    // iOS entrega um único plano em BGRA8888 — é o caso simples.
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.bgra8888,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  static InputImage? _fromAndroidYuv420(CameraImage image, InputImageRotation rotation) {
    // Android entrega YUV_420_888 em 3 planos separados (Y, U, V). O ML Kit
    // no Android aceita NV21, que é Y seguido de VU intercalado — então
    // concatenamos os planos nessa ordem.
    if (image.planes.length < 3) return null;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final nv21 = _yuv420ToNv21(
      width: image.width,
      height: image.height,
      yPlane: yPlane,
      uPlane: uPlane,
      vPlane: vPlane,
    );

    return InputImage.fromBytes(
      bytes: nv21,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width,
      ),
    );
  }

  static Uint8List _yuv420ToNv21({
    required int width,
    required int height,
    required Plane yPlane,
    required Plane uPlane,
    required Plane vPlane,
  }) {
    final ySize = width * height;
    final uvSize = width * height ~/ 2;
    final nv21 = Uint8List(ySize + uvSize);

    // Plano Y: copia linha a linha respeitando o stride (bytesPerRow pode
    // ser maior que width por padding).
    var offset = 0;
    for (var row = 0; row < height; row++) {
      final start = row * yPlane.bytesPerRow;
      nv21.setRange(offset, offset + width, yPlane.bytes, start);
      offset += width;
    }

    // Planos U/V: intercalados como V,U (NV21) — o "bytesPerPixel" do plano
    // U/V no Android costuma ser 2 (formato semi-planar). O pacote `camera`
    // expõe esse valor como `bytesPerPixel` (equivalente ao pixelStride
    // nativo do Android).
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;
    var uvOffset = ySize;
    for (var row = 0; row < height ~/ 2; row++) {
      for (var col = 0; col < width ~/ 2; col++) {
        final uIndex = row * uvRowStride + col * uvPixelStride;
        final vIndex = row * uvRowStride + col * uvPixelStride;
        nv21[uvOffset++] = vPlane.bytes[vIndex];
        nv21[uvOffset++] = uPlane.bytes[uIndex];
      }
    }

    return nv21;
  }

  static InputImageRotation? _rotationFromSensorOrientation(int sensorOrientation) {
    return InputImageRotationValue.fromRawValue(sensorOrientation);
  }
}
