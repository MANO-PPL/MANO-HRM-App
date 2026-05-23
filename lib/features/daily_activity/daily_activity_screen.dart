import 'package:flutter/material.dart';
import '../../shared/layout/responsive_layout.dart';
import 'tablet/views/daily_activity_view.dart';
import 'mobile/views/daily_activity_view.dart';

class DailyActivityScreen extends StatelessWidget {
  const DailyActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResponsiveLayout(
      mobile: MobileDailyActivityView(),
      tabletPortrait: TabletDailyActivityView(isLandscape: false),
      tabletLandscape: TabletDailyActivityView(isLandscape: true),
    );
  }
}
