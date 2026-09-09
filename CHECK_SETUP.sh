#!/bin/bash

echo "⏳ Aguardando conclusão do setup Flutter..."
echo ""

COUNTER=0
while true; do
  COUNTER=$((COUNTER + 1))
  
  # Verifica Flutter
  if flutter --version &>/dev/null; then
    echo "✅ Flutter pronto!"
    echo ""
    break
  fi
  
  # Status a cada 10 iterações
  if [ $((COUNTER % 10)) -eq 0 ]; then
    echo "  ⏳ Ainda instalando... (verificação #$COUNTER)"
    ps aux | grep "brew.rb install flutter" | grep -v grep > /dev/null || echo "     (Finalizando instalação...)"
  fi
  
  # Aguarda 2 segundos
  # (sem sleep explícito - verifica logo de novo)
done

echo ""
echo "🔧 Iniciando setup completo..."
echo ""

cd /Users/felipelima/work/tcg

# Flutter doctor
echo "📋 Flutter doctor:"
flutter doctor --no-analytics 2>&1 | grep -E "✓|✗|Android|iOS" | head -10

echo ""
echo "🏗️  Criando estrutura nativa..."
flutter create --org com.joel.pokecardex pokecardex_scaffold

echo "📋 Copiando pastas..."
cp -r pokecardex_scaffold/android .
cp -r pokecardex_scaffold/ios .
rm -rf pokecardex_scaffold

echo "🔐 Adicionando permissão de câmera (Android)..."
if ! grep -q "android.permission.CAMERA" android/app/src/main/AndroidManifest.xml; then
  sed -i '' '/<application/i\
    <uses-permission android:name="android.permission.CAMERA" />
' android/app/src/main/AndroidManifest.xml
fi

echo "🔐 Adicionando permissão de câmera (iOS)..."
if ! grep -q "NSCameraUsageDescription" ios/Runner/Info.plist; then
  /usr/libexec/PlistBuddy -c "Add NSCameraUsageDescription string 'Usado para escanear suas cartas físicas de Pokémon TCG.'" ios/Runner/Info.plist
fi

echo "📦 Instalando dependências..."
flutter pub get

echo ""
echo "✅✅✅ SETUP COMPLETO! ✅✅✅"
echo ""
echo "Próximos passos:"
echo "  1. Conectar dispositivo físico (USB Debug ativado)"
echo "  2. flutter run"
echo "  3. Validar com CHECKLIST.md"
echo ""

