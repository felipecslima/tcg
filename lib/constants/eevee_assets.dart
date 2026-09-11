abstract final class EeveeAssets {
  static String path(String name) => 'assets/eevee/$name.png';

  static const brand = 'sylveon';
  static const defaultAvatar = 'sylveon';

  static const all = [
    'sylveon',
    'eevee',
    'espeon',
    'umbreon',
    'vaporeon',
    'jolteon',
    'flareon',
    'leafeon',
    'glaceon',
  ];

  static const guardians = {
    'Kanto': 'flareon',
    'Johto': 'umbreon',
    'Hoenn': 'vaporeon',
    'Sinnoh': 'glaceon',
    'Unova': 'leafeon',
  };
}
