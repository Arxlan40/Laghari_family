import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/family_member.dart';

class MemberAvatarWidget extends StatelessWidget {
  final FamilyMember member;
  final double radius;
  final bool showStatusIndicator;

  const MemberAvatarWidget({
    super.key,
    required this.member,
    this.radius = 28,
    this.showStatusIndicator = true,
  });

  Color get _statusColor {
    switch (member.aliveStatus) {
      case AliveStatus.alive:
        return AppColors.aliveColor;
      case AliveStatus.deceased:
        return AppColors.deceasedColor;
      case AliveStatus.unknown:
        return AppColors.unknownStatusColor;
    }
  }

  Color get _genderBorderColor {
    return member.isFemale ? AppColors.femaleAccent : AppColors.maleAccent;
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomImage = member.imageUrl.isNotEmpty;
    final fallbackAsset = member.isFemale
        ? 'assets/images/female_avatar.jpg'
        : 'assets/images/male_avatar.jpg';

    return Stack(
      children: [
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _genderBorderColor.withValues(alpha: 0.8),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _genderBorderColor.withValues(alpha: 0.2),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipOval(
            child: hasCustomImage
                ? (member.imageUrl.startsWith('data:image')
                    ? Image.memory(
                        base64Decode(member.imageUrl.split(',').last),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Image.asset(fallbackAsset, fit: BoxFit.cover),
                      )
                    : CachedNetworkImage(
                        imageUrl: member.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.darkCard,
                          child: const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Image.asset(
                          fallbackAsset,
                          fit: BoxFit.cover,
                        ),
                      ))
                : Image.asset(
                    fallbackAsset,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        if (showStatusIndicator)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.55,
              height: radius * 0.55,
              decoration: BoxDecoration(
                color: _statusColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.darkBackground,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _statusColor.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  member.aliveStatus == AliveStatus.alive
                      ? Icons.check
                      : (member.aliveStatus == AliveStatus.deceased
                          ? Icons.close
                          : Icons.help_outline),
                  size: radius * 0.35,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
