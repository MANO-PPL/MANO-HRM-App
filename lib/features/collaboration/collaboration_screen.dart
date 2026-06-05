import 'package:flutter/material.dart';
import '../../shared/layout/responsive_layout.dart';
import 'mobile/collaboration_mobile_view.dart';
import 'tablet/collaboration_tablet_view.dart';

class CollaborationScreen extends StatelessWidget {
  const CollaborationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResponsiveLayout(
      mobile: CollaborationMobileView(),
      tabletPortrait: CollaborationTabletView(),
      tabletLandscape: CollaborationTabletView(),
    );
  }
}
