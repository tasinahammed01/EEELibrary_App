import 'package:flutter/material.dart';

import '../../../core/constants/design_tokens.dart';
import '../../../core/widgets/brand.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.onNotifications,
    required this.onProfile,
  });
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: onNotifications,
            constraints: const BoxConstraints(
              minWidth: AppSizes.touchTarget,
              minHeight: AppSizes.touchTarget,
            ),
            icon: const Badge(
              smallSize: AppSpace.xs,
              backgroundColor: AppColors.gold,
              child: Icon(
                Icons.notifications_none_rounded,
                color: AppColors.navy,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Open profile',
            onPressed: onProfile,
            constraints: const BoxConstraints(
              minWidth: AppSizes.touchTarget,
              minHeight: AppSizes.touchTarget,
            ),
            icon: const CircleAvatar(
              backgroundColor: AppColors.blueTint,
              child: Icon(Icons.person_outline, color: AppColors.blue),
            ),
          ),
        ],
      );
      // Stack the actions when the full brand lockup would become cramped.
      if (constraints.maxWidth < AppSizes.contentWidth - AppSpace.xl * 2 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.2) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Brand(),
            const SizedBox(height: AppSpace.xs),
            Align(alignment: Alignment.centerRight, child: actions),
          ],
        );
      }
      return Row(
        children: [
          const Expanded(child: Brand()),
          const SizedBox(width: AppSpace.xs),
          actions,
        ],
      );
    },
  );
}
