import 'package:flutter/material.dart';
import 'package:flutter_application/shared/layout/responsive_layout.dart';
import 'package:flutter_application/features/attendance/views/attendance_mobile_portrait_view.dart';
import 'package:flutter_application/features/attendance/views/attendance_tablet_portrait_view.dart';
import 'package:flutter_application/features/attendance/views/attendance_tablet_landscape_view.dart';

class AttendancePage extends StatelessWidget {
  const AttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResponsiveLayout(
      mobile: MobileMyAttendanceContent(),
      tabletPortrait: AttendanceTabletPortraitView(),
      tabletLandscape: AttendanceTabletLandscapeView(),
      desktop: AttendanceTabletLandscapeView(),
    );
  }
}
