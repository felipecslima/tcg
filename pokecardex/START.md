# 🚀 START — Comece aqui

**Tempo total:** ~30 min (setup) + teste com cartas físicas

## Passo 1: Verifica pré-requisitos (5 min)

```bash
flutter doctor
```

Tudo deve ter ✓ (exceto web/analytics que pode ignorar). Se algo está ❌:
→ Instala Flutter: https://flutter.dev/docs/get-started/install

## Passo 2: Gera estrutura nativa (10 min)

Este projeto tem `lib/` e `pubspec.yaml` prontos, mas falta `android/` e `ios/`.

```bash
# Num diretório FORA do pokecardex, cria um scaffold temporário
flutter create --org com.joel.pokecardex pokecardex_scaffold

# Copia as pastas nativas pra dentro do pokecardex
cp -r pokecardex_scaffold/android pokecardex/
cp -r pokecardex_scaffold/ios pokecardex/

# Limpa o temporário
rm -rf pokecardex_scaffold

# Entra no projeto final
cd pokecardex
```

## Passo 3: Adiciona permissões (5 min)

**Android:** Abre `android/app/src/main/AndroidManifest.xml`

Procura por `<manifest`. Logo antes de `<application>`, adiciona:
```xml
<uses-permission android:name="android.permission.CAMERA" />
```

**iOS:** Abre `ios/Runner/Info.plist`

Procura pelo `<dict>` principal no final do arquivo. Adiciona:
```xml
<key>NSCameraUsageDescription</key>
<string>Usado para escanear suas cartas físicas de Pokémon TCG.</string>
```

Confirma que `ios/Podfile` tem:
```ruby
platform :ios, '15.5'
```

## Passo 4: Instala dependências (3 min)

```bash
cd pokecardex
flutter pub get
```

## Passo 5: Rodar!

Conecta um dispositivo físico (Android com USB Debug ativado, ou iPhone/iPad confiando no Mac).

```bash
flutter run
```

**Primeira vez** vai levar 2-3 min compilando. Depois é rápido.

## Passo 6: Testa tudo (7 min)

Abre o app, testa na ordem:

1. ✓ Câmera abre sem erro
2. ✓ Seleciona "Inglês" → lista de sets carrega
3. ✓ Clica num set pequeno → carrega cartas
4. ✓ Aponta a câmera pra uma carta Pokémon → "Lendo: ..." aparece
5. ✓ Carta é reconhecida e **vibra**
6. ✓ Clica "Revisar" → vê resultado
7. ✓ Clica "Salvar sessão" → arquivo JSON é criado

**Se algo falhar:** Pula pra [DEBUG.md](./DEBUG.md)

## Próximo: Teste real com suas cartas

Seleciona um set (português se tiver cartas PT, senão inglês) e escaneia 5-10 cartas de verdade.

**Esperado:** 80-90% de reconhecimento em boa iluminação.

Se muitas pendências (< 70%): [DEBUG.md](./DEBUG.md) → "Câmera reconhece texto, mas cartas não casam"

## Quando tiver validado tudo

Abre [CHECKLIST.md](./CHECKLIST.md) e marca os itens conforme avança.

## Documentação rápida

- **Como rodar?** → [SETUP.md](./SETUP.md)
- **Algo não funciona?** → [DEBUG.md](./DEBUG.md)
- **Quer entender o design?** → [ARCHITECTURE.md](./ARCHITECTURE.md)
- **Qual arquivo editar?** → [ORGANIZATION.md](./ORGANIZATION.md)
- **Estado atual & roadmap?** → [HANDOFF.md](./HANDOFF.md)

## Problema comum: "Câmera não abre"

```bash
# Android: ativa USB Debug
adb devices  # verifica se o dispositivo aparece

# iOS: desbloqueia + confia no computador
```

Se ainda não funciona, ver [DEBUG.md](./DEBUG.md) → "Câmera não abre"

## Help!

| Se... | Então... |
|------|---------|
| `flutter: command not found` | Instalar Flutter (link acima) |
| Câmera não abre | [DEBUG.md](./DEBUG.md) → "Câmera não abre" |
| OCR nunca reconhece | [DEBUG.md](./DEBUG.md) → "Câmera não reconhece texto" |
| Muitas pendências | [DEBUG.md](./DEBUG.md) → "Câmera reconhece mas cartas não casam" |
| App crasha | Rodar `flutter run -v` e procurar por erro |

---

**Pronto? Vamos lá!** 🎯

```bash
cd pokecardex
flutter run
```

Depois que funcionar, volta aqui e segue pra [CHECKLIST.md](./CHECKLIST.md).
