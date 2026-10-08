// lib/shared/widgets/date_range_filter.dart
// ─────────────────────────────────────────────────────────────────────────────
// Filtre de période réutilisable (S14).
// Affiche 4 chips horizontaux : Tout / Aujourd'hui / Cette semaine / Ce mois.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

enum DateFilter {
  all('Tout'),
  today('Aujourd\'hui'),
  week('Cette semaine'),
  month('Ce mois');

  final String label;
  const DateFilter(this.label);
}

class DateRangeFilter extends StatelessWidget {
  final DateFilter selected;
  final ValueChanged<DateFilter> onChanged;

  const DateRangeFilter({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: DateFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = DateFilter.values[i];
          final isSelected = f == selected;
          return GestureDetector(
            onTap: () => onChanged(f),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                f.label,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
