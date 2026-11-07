import 'package:flutter/material.dart';
import 'package:flutter_application/shared/layout/responsive_layout.dart';
import 'package:flutter_application/features/payroll/views/payroll_mobile_portrait_view.dart';
import 'package:flutter_application/features/payroll/views/payroll_tablet_portrait_view.dart';
import 'package:flutter_application/features/payroll/views/payroll_tablet_landscape_view.dart';

class PayrollScreen extends StatelessWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResponsiveLayout(
      mobile: PayrollScreenMobile(),
      tabletPortrait: PayrollScreenTablet(isLandscape: false),
      tabletLandscape: PayrollTabletLandscapeView(),
    );
  }
}

// [mod:2026-02-25T11:30:00+05:30]

// [upd:2026-05-05T11:30:00+05:30]

// [upd:2026-05-13T09:00:00+05:30]
