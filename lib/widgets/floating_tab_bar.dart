import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class TabItem {
  const TabItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Tab bar flutuante do design (README § Navegação).
/// left/right 14, bottom 22, height 66, raio 26, fundo translúcido + blur 22.
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<TabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.tabBar),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: AppColors.scrim,
              borderRadius: BorderRadius.circular(AppRadii.tabBar),
              border: Border.all(color: AppColors.border1),
              boxShadow: AppShadows.raised,
            ),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => onTap(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            items[i].icon,
                            size: 20,
                            color: i == currentIndex
                                ? AppColors.primary
                                : AppColors.text5,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            items[i].label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: i == currentIndex
                                  ? AppColors.primary
                                  : AppColors.text5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
