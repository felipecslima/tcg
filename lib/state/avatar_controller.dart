import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/eevee_assets.dart';

class AvatarController extends ChangeNotifier {
  AvatarController() {
    _load();
  }

  static const _key = 'avatar';

  String _avatar = EeveeAssets.defaultAvatar;
  String get avatar => _avatar;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null && EeveeAssets.all.contains(saved)) {
        _avatar = saved;
        notifyListeners();
      }
    } on Exception {
      // Fallback silencioso — mantém defaultAvatar
    }
  }

  Future<void> setAvatar(String name) async {
    if (!EeveeAssets.all.contains(name) || _avatar == name) return;
    _avatar = name;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, name);
  }
}
