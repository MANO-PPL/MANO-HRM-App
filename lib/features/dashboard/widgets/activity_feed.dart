import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/shared/widgets/glass_container.dart';
import 'package:flutter_application/shared/models/dashboard_model.dart';

class ActivityFeed extends StatefulWidget {
  final List<ActivityLog> activities;

  const ActivityFeed({super.key, required this.activities});

  @override
  State<ActivityFeed> createState() => _ActivityFeedState();
}

class _ActivityFeedState extends State<ActivityFeed> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    if (widget.activities.isEmpty) {
      return const GlassContainer(
        padding: EdgeInsets.all(24),
        child: Center(child: Text("No live activity today")),
      );
    }

    // Threshold logic
    final displayedActivities = _showAll ? widget.activities : widget.activities.take(5).toList();
    final hasMore = widget.activities.length > 5;

    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.1);
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodySmall?.color;

    return GlassContainer(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Activity',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 0),
          
          // Scrollable List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayedActivities.length,
            separatorBuilder: (context, index) => Divider(
              height: 14,
              color: dividerColor,
            ),
            itemBuilder: (context, index) {
              final activity = displayedActivities[index];
              final avatarChar = activity.user.isNotEmpty ? activity.user[0] : '?';
              
              final color = Colors.primaries[index % Colors.primaries.length];

              return Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: color.withValues(alpha: 0.1),
                    child: Text(
                      avatarChar,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.user,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        Text(
                          '${activity.role} • ${activity.action}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: subTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: dividerColor),
                    ),
                    child: Text(
                      activity.time,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: subTextColor,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          
          if (hasMore) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _showAll = !_showAll;
                  });
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.2) : dividerColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  _showAll ? 'Show Less' : 'View Full History', 
                  style: GoogleFonts.poppins(
                    fontSize: 12, 
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).primaryColor
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// [mod:2026-02-22T12:00:00+05:30]

// [upd:2026-05-10T14:00:00+05:30]

// [rev:2026-08-25T18:00:00+05:30]
