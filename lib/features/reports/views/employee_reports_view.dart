import 'package:flutter/material.dart';
import 'package:flutter_application/shared/layout/responsive_layout.dart';
import 'package:flutter_application/features/reports/views/employee_reports_mobile_portrait_view.dart';
import 'package:flutter_application/features/reports/views/employee_reports_tablet_portrait_view.dart';
import 'package:flutter_application/features/reports/views/employee_reports_tablet_landscape_view.dart';

/// Responsive wrapper for Employee Reports, routing cleanly to:
/// - Mobile Portrait (`EmployeeReportsMobilePortraitView`)
/// - Tablet Portrait (`EmployeeReportsTabletPortraitView`)
/// - Tablet Landscape / Desktop (`EmployeeReportsTabletLandscapeView`)
class EmployeeReportsView extends StatelessWidget {
  const EmployeeReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResponsiveLayout(
      mobile: EmployeeReportsMobilePortraitView(),
      tabletPortrait: EmployeeReportsTabletPortraitView(),
      tabletLandscape: EmployeeReportsTabletLandscapeView(),
      desktop: EmployeeReportsTabletLandscapeView(),
    );
  }
}
