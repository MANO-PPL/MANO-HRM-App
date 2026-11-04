import 'package:flutter/material.dart';
import 'package:flutter_application/shared/layout/responsive_layout.dart';
import 'package:flutter_application/features/collaboration/views/collaboration_mobile_portrait_view.dart';
import 'package:flutter_application/features/collaboration/views/collaboration_tablet_portrait_view.dart';
import 'package:flutter_application/features/collaboration/views/collaboration_tablet_landscape_view.dart';

class CollaborationScreen extends StatelessWidget {
  const CollaborationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResponsiveLayout(
      mobile: CollaborationMobileView(),
      tabletPortrait: CollaborationTabletView(),
      tabletLandscape: CollaborationTabletLandscapeView(),
    );
  }
}

// [mod:2026-02-23T14:00:00+05:30]

// [upd:2026-05-06T11:30:00+05:30]

// [upd:2026-05-12T09:00:00+05:30]
