import 'package:flutter/material.dart';
import 'package:flutter_application/shared/layout/responsive_layout.dart';
import 'package:flutter_application/features/reports/views/reports_mobile_portrait_view.dart';
import 'package:flutter_application/features/reports/views/reports_tablet_portrait_view.dart';
import 'package:flutter_application/features/reports/views/reports_tablet_landscape_view.dart';

import 'package:provider/provider.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/features/reports/views/employee_reports_view.dart';

class ReportsView extends StatelessWidget {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).user;
    if (user != null && user.isEmployee) {
      return const EmployeeReportsView();
    }

    return const ResponsiveLayout(
      mobile: ReportsMobileView(),
      tabletPortrait: ReportsTabletPortraitView(),
      tabletLandscape: ReportsTabletLandscapeView(),
      desktop: ReportsTabletLandscapeView(),
    );
  }
}

// [upd:2026-04-27T09:00:00+05:30]

// [upd:2026-05-13T11:30:00+05:30]
