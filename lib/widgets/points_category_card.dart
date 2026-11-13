import 'package:flutter/material.dart';

/// Satu kartu ringkas yang menggabungkan filter kategori olahraga dan saldo poin.
class PointsCategoryCard extends StatelessWidget {
  const PointsCategoryCard({
    super.key,
    required this.points,
    required this.selectedCategory,
    required this.onCategoryChanged,
    this.pointsError,
  });

  final int points;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final String? pointsError;

  static const categories = [
    ('Semua', Icons.sports, 'Semua'),
    ('Futsal', Icons.sports_soccer, 'Futsal'),
    ('Badminton', Icons.sports_tennis, 'Badminton'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: categories.map((category) {
                final isSelected = category.$1 == selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Tooltip(
                    message: category.$3,
                    child: Semantics(
                      label: 'Kategori ${category.$3}',
                      button: true,
                      selected: isSelected,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => onCategoryChanged(category.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF00A32A)
                                : const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            category.$2,
                            color: isSelected ? Colors.white : Colors.black87,
                            size: 25,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Container(width: 1, height: 42, color: Colors.grey.shade200),
          const SizedBox(width: 12),
          Tooltip(
            message: pointsError ?? 'Total poin kamu',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on_rounded,
                  color: Color(0xFFFFB300),
                  size: 30,
                ),
                const SizedBox(width: 6),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$points',
                      style: const TextStyle(
                        color: Color(0xFF1E2A2B),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      pointsError == null ? 'POIN' : 'LOGIN',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
