import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class HamdardUserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;

  const HamdardUserAvatar({
    super.key,
    required this.imageUrl,
    required this.name,
    double? size,
    double? radius,
    this.backgroundColor,
    this.textColor,
  }) : size = radius != null ? (radius * 2) : (size ?? 40);

  @override
  Widget build(BuildContext context) {
    final url = (imageUrl ?? '').trim();
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';

    Widget fallbackWidget() {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.emerald.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.bold,
            color: textColor ?? AppColors.emerald,
          ),
        ),
      );
    }

    if (url.isEmpty) {
      return fallbackWidget();
    }

    if (url.startsWith('data:image')) {
      try {
        final comma = url.indexOf(',');
        final b64 = comma != -1 ? url.substring(comma + 1) : url;
        return ClipOval(
          child: Image.memory(
            base64Decode(b64),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => fallbackWidget(),
          ),
        );
      } catch (_) {
        return fallbackWidget();
      }
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (ctx, targetUrl) => Container(
          width: size,
          height: size,
          color: Colors.grey.withValues(alpha: 0.1),
          child: const Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald),
            ),
          ),
        ),
        errorWidget: (ctx, targetUrl, error) => fallbackWidget(),
      ),
    );
  }
}
