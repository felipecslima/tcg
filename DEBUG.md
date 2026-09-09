# DEBUG — Troubleshooting do PokeCardex Scanner MVP

Dicas de debug para quando algo não funcionar como esperado.

## Verificar logs em tempo real

```bash
flutter run -v
```

Procure por linhas com `[pokecardex.camera]` e `[pokecardex.scanner]` — são os logs do nosso app.

## Problema: Câmera não abre

**Sintomas:** App exibe "Erro ao acessar câmera" quando tenta começar a escanear.

### Checklist

1. **Permissões concedidas?**
   - Android: Settings → Apps → PokeCardex → Permissions → Camera (On)
   - iOS: Settings → PokeCardex → Camera (Allow)
   - Se em dúvida, desinstale o app, reinstale e conceda permissões na primeira execução

2. **Dispositivo tem câmera?**
   ```bash
   flutter run -v | grep -i camera
   ```
   Deve listar pelo menos uma câmera traseira.

3. **Câmera já está aberta por outro app?**
   Feche Câmera, Zoom, Meet, qualquer app que use câmera.

4. **iOS específico:** Xcode/simulador está bloqueando?
   ```bash
   flutter clean
   flutter pub get
   flutter run -v
   ```

### Se nada funcionar
Envie o output de:
```bash
flutter doctor -v
```

## Problema: Câmera abre, mas não reconhece NENHUM texto

**Sintomas:** Aponta pra uma carta em boa iluminação mas "Lendo: ..." nunca aparece.

### Checklist

1. **CameraImageConverter falhando silenciosamente** — o mais provável.
   
   Ative debug logging no arquivo `lib/screens/scanner_screen.dart`:
   ```bash
   flutter run -v 2>&1 | grep pokecardex
   ```
   
   Se vir `Failed to convert camera image to InputImage`, o problema é:
   - iOS: formato BGRA8888 não está sendo interpretado corretamente
   - Android: YUV420 não está sendo convertido pra NV21 direito
   
   **Fix temporário:** Abra `lib/services/camera_image_converter.dart`, procure por `confidenceThreshold` (não, calma, está em card_matcher) — não, o fix é diferente:
   
   Mude em `scanner_screen.dart` a linha com `imageFormatGroup`:
   ```dart
   // Tente sem forçar o formato:
   // imageFormatGroup: ImageFormatGroup.yuv420,
   ```
   Remova essa linha (comentar não funciona, tem que remover).

2. **Iluminação fraca?**
   Teste com a câmera frontal do dispositivo apontando pra uma janela bem iluminada. Se a câmera vê bem, o problema é de iluminação, não do reconhecimento.

3. **Carta muito pequena na tela?**
   OCR funciona melhor quando o texto ocupa pelo menos ~30% da câmera. Aproxime a carta.

4. **Texto impresso muito pequeno?**
   Cartas Pokémon têm o número em ~8-12pt. Se estiver muito longe, OCR falha.

### Logs detalhados

Para ver EXATAMENTE o que está saindo do OCR:

Em `lib/screens/scanner_screen.dart`, na função `_processLatestFrame()`, adicione temporariamente:
```dart
developer.log('Raw OCR output: "$text"', name: 'pokecardex.scanner');
```

Depois procure pela linha:
```bash
flutter run -v 2>&1 | grep "Raw OCR output"
```

Se o texto está saindo (mas não casando), o problema é no matcher, não no OCR (ver seção abaixo).

Se nada aparece:
- iOS: `_fromIosBgra` está recebendo formato errado
- Android: `_fromAndroidYuv420` não está conversando corretamente com os planos

Nesse caso, adicione em `camera_image_converter.dart`:
```dart
developer.log('Image format: ${image.format.group}, planes: ${image.planes.length}', name: 'pokecardex.camera');
```

Compare a saída com os comentários esperados (BGRA no iOS deve ter 1 plano, YUV420 no Android deve ter 3).

## Problema: Câmera reconhece texto, mas cartas não casam

**Sintomas:** "Lendo: Charizard ..." aparece, mas não vira match confirmado. Vai reto pra "Pendentes".

### Debug

1. **Qual é a confiança?**
   Em `lib/services/card_matcher.dart`, mude temporariamente:
   ```dart
   confidenceThreshold = 0.30  // de 0.55 pra mais baixo
   ```
   Se começar a funcionar, o threshold está muito alto pra suas cartas/OCR.

2. **Logs de matching:**
   Em `scanner_screen.dart`, você já tem:
   ```dart
   developer.log('Match found: ${result.card!.name} (score: ${result.score})', name: 'pokecardex.scanner');
   developer.log('No confident match for text: $text (best score: ${result.score})', name: 'pokecardex.scanner');
   ```
   
   Execute:
   ```bash
   flutter run -v 2>&1 | grep -E "(Match found|No confident match)"
   ```
   
   Anote o score mais alto. Se está entre 0.30-0.55, é por isso que não casa.

3. **Qual carta quase casou?**
   Modifique temporariamente em `card_matcher.dart`:
   ```dart
   // No final de match():
   print('Best match: $best (score: $bestScore) for input: "$normalizedInput"');
   ```
   Veja qual carta está ficando mais próxima.

4. **O número está sendo lido?**
   Se a carta é "Charizard #006" e o OCR leu só "Charizard" (sem número), o score fica ruim. Tente aproximar mais pra que o número fique bem legível.

### Ajustes

- **Se score é 0.35-0.55:** Abaixe o `confidenceThreshold` pra 0.35-0.40
- **Se score é < 0.30:** O OCR está lendo algo bem diferente do esperado. Tente outra carta ou melhor iluminação.
- **Se o número nunca é lido:** Aumente o zoom/proxe a câmera — o número precisa ser bem legível.

## Problema: "Pendências" acumulando, muitos matches perdidos

**Sintomas:** Na revisão, tem 3 cartas reconhecidas mas 15 pendentes. Esperava mais matches.

### Análise

1. **Seu threshold é muito alto:**
   Abaixe em `card_matcher.dart`:
   ```dart
   CardMatcher(confidenceThreshold: 0.40)  // de 0.55
   ```

2. **OCR está ruidoso:**
   O texto está saindo com muito lixo, ex: "Charizard HP 120 Basic" em vez de só "Charizard". Isso reduz o score.
   
   - Melhor iluminação
   - Ângulo mais frontal (não inclinado)
   - Remova sombras

3. **Carta em mau estado:**
   Letras desgastadas/apagadas = OCR falha. Normal pra cartas antigas.

## Problema: App crasha ao abrir

**Erro:** `flutter: [ERROR:flutter/runtime/dart_vm_initializer.cc:41] Unhandled Exception:`

### Checklist

1. **Permissões no manifest/plist?**
   Ver [SETUP.md](./SETUP.md) — seção "Permissões".

2. **Dependências instaladas?**
   ```bash
   flutter pub get
   flutter pub upgrade
   ```

3. **Invalidar cache:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

4. **Flutter desatualizado?**
   ```bash
   flutter upgrade
   flutter run
   ```

### Se o erro tiver `Camera` no nome

Provavelmente falta permissão de câmera. Ver seção "Câmera não abre" acima.

## Problema: JSON de resultado não é criado

**Sintomas:** Clica em "Salvar sessão (JSON local)", não vê confirmação.

### Debug

1. **Permissão de escrita?**
   - Android: Settings → Apps → PokeCardex → Permissions → Files (On)
   - iOS: Documents deve estar acessível por padrão

2. **Onde está o arquivo?**
   - Android: Settings → Storage → Apps → PokeCardex ou `adb shell am start -a android.intent.action.VIEW -t "file/*" -d "file:///storage/emulated/0/Documents"`
   - iOS: Xcode → Window → Devices and Simulators → App Container → Documents

3. **Arquivo é gerado mas vazio?**
   Procure por `scan_*.json` em Documents. Se existe mas está vazio, é bug. Abra issue.

## Teste rápido pra validar tudo

```bash
# Terminal 1: Rodando app com logs
flutter run -v 2>&1 | tee flutter_run.log

# Terminal 2: Monitorar logs em tempo real
tail -f flutter_run.log | grep pokecardex

# Depois de rodar:
grep "pokecardex" flutter_run.log | head -50
```

Procure por:
- `Image format:` — deve ser `yuv420` (Android) ou não aparecer (iOS é implícito)
- `Match found:` — sucesso!
- `No confident match:` — falha esperada
- Qualquer erro/exception

## Se ainda tiver problemas

1. Rode `flutter doctor -v` completo e salve output
2. Rode `flutter run -v` uma vez, escaneia 3 cartas, salva output
3. Procure pelo arquivo JSON criado
4. Compartilhe tudo com mais detalhes sobre:
   - Que cartas tentou?
   - Qual idioma (PT/EN)?
   - Qual set?
   - Que mensagens de erro apareceram?
   - Qual dispositivo (modelo, OS)?

## Ajustes pós-validação

Uma vez que tudo funciona com sua primeira sessão, você pode:

1. **Aumentar score thresholds** se muitas pendências forem falsas-negativas
2. **Adicionar mais idiomas** (script diferente em `text_recognition_script`)
3. **Calibrar** o intervalo de processamento (está em 600ms, pode reduzir pra 400ms pra mais rápido)

Ver [ARCHITECTURE.md](./ARCHITECTURE.md) pra detalhes.
