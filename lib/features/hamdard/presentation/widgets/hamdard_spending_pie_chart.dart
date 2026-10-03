import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/hamdard_spending_category.dart';
import '../../repositories/hamdard_repository.dart';

class HamdardSpendingPieChart extends StatefulWidget {
  final Map<HamdardSpendingCategory, int> categorySpending;
  final int totalSpending;
  final bool isUrdu;

  const HamdardSpendingPieChart({
    super.key,
    required this.categorySpending,
    required this.totalSpending,
    this.isUrdu = false,
  });

  @override
  State<HamdardSpendingPieChart> createState() => _HamdardSpendingPieChartState();
}

class _HamdardSpendingPieChartState extends State<HamdardSpendingPieChart> {
  HamdardSpendingCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter categories with spending > 0
    final activeCategories = widget.categorySpending.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (widget.totalSpending <= 0 || activeCategories.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text(
              widget.isUrdu ? 'اس مدت کے لیے کوئی اخراجات نہیں' : 'No spending in this period',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final selected = _selectedCategory ?? activeCategories.first.key;
    final selectedAmount = widget.categorySpending[selected] ?? 0;
    final selectedPct = (selectedAmount / widget.totalSpending) * 100;

    return Column(
      children: [
        // Donut Chart Canvas with Center Stat Callout
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTapUp: (details) {
                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox == null) return;
                  final center = const Offset(110, 110);
                  final touchPosition = details.localPosition;
                  final dx = touchPosition.dx - center.dx;
                  final dy = touchPosition.dy - center.dy;
                  var angle = math.atan2(dy, dx);
                  if (angle < 0) angle += 2 * math.pi;

                  double currentAngle = 0;
                  for (final item in activeCategories) {
                    final sweep = (item.value / widget.totalSpending) * 2 * math.pi;
                    if (angle >= currentAngle && angle <= currentAngle + sweep) {
                      setState(() => _selectedCategory = item.key);
                      break;
                    }
                    currentAngle += sweep;
                  }
                },
                child: CustomPaint(
                  size: const Size(220, 220),
                  painter: _DonutChartPainter(
                    items: activeCategories,
                    total: widget.totalSpending,
                    selectedCategory: selected,
                    isDark: isDark,
                  ),
                ),
              ),
              // Center Information
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(selected.icon, size: 20, color: selected.color),
                    const SizedBox(height: 2),
                    Text(
                      '${selectedPct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: selected.color,
                      ),
                    ),
                    Text(
                      selected.label(widget.isUrdu),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Selected Category Callout Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected.color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected.color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(selected.icon, color: selected.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected.label(widget.isUrdu),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      '${selectedPct.toStringAsFixed(1)}% of total spending',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                HamdardRepository.formatPkr(selectedAmount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: selected.color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Interactive Category Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: activeCategories.map((entry) {
            final isSelected = entry.key == selected;
            final pct = (entry.value / widget.totalSpending) * 100;
            return ChoiceChip(
              avatar: Icon(entry.key.icon, size: 14, color: isSelected ? Colors.white : entry.key.color),
              label: Text('${entry.key.label(widget.isUrdu)} (${pct.toStringAsFixed(0)}%)'),
              selected: isSelected,
              selectedColor: entry.key.color,
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
              onSelected: (_) => setState(() => _selectedCategory = entry.key),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<MapEntry<HamdardSpendingCategory, int>> items;
  final int total;
  final HamdardSpendingCategory selectedCategory;
  final bool isDark;

  _DonutChartPainter({
    required this.items,
    required this.total,
    required this.selectedCategory,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 28.0;

    double startAngle = -math.pi / 2;

    for (final item in items) {
      final sweepAngle = (item.value / total) * 2 * math.pi;
      final isSelected = item.key == selectedCategory;

      final paint = Paint()
        ..color = item.key.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? strokeWidth + 6 : strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.total != total ||
        oldDelegate.selectedCategory != selectedCategory ||
        oldDelegate.items.length != items.length;
  }
}
