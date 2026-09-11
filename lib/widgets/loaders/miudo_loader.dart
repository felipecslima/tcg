import 'package:flutter/material.dart';

import 'eevee_loader_base.dart';

class MiudoLoader extends StatelessWidget {
  const MiudoLoader({super.key, this.size = 20});

  final double size;

  static const _names = ['sylveon', 'eevee', 'espeon'];

  @override
  Widget build(BuildContext context) {
    return EeveeCycler(
      names: _names,
      size: size,
      cycleDuration: const Duration(milliseconds: 2400),
    );
  }
}
