import 'package:flutter/material.dart';
import '../../mobile/views/leave_mobile_view.dart';
import 'leave_tablet_portrait.dart';
import 'leave_tablet_landscape.dart';

class LeaveView extends StatelessWidget {
  const LeaveView({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return const LeaveMobileView();
        }
        return OrientationBuilder(
          builder: (context, orientation) {
            if (orientation == Orientation.portrait) {
              return const LeaveTabletPortrait();
            } else {
              return const LeaveTabletLandscape();
            }
          },
        );
      },
    );
  }
}
