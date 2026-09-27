import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../exercise_plan/presentation/screens/exercise_plan_screen.dart';
import '../../../wearable_connection/presentation/screens/wearable_connection_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'id': 1,
      'title': 'ROM Target Goal Updated',
      'body': 'Dr. Tehreem increased your Elbow Flexion goal from 80° to 90° following your recovery milestone.',
      'time': '10:15 AM Today',
      'type': 'doctor',
      'unread': true,
      'icon': Icons.medical_services_rounded,
      'color': AppTheme.primaryTeal,
    },
    {
      'id': 2,
      'title': 'Prescribed Session Reminder',
      'body': 'Time for today\'s Elbow Flexion & Extension protocol (3 sets × 10 reps).',
      'time': '2:00 PM Today',
      'type': 'reminder',
      'unread': true,
      'icon': Icons.alarm_rounded,
      'color': AppTheme.amber,
    },
    {
      'id': 3,
      'title': 'Clinical Form Score Verified',
      'body': 'Your latest session was reviewed on the Ayub Medical Complex portal: 94% optimal joint stability.',
      'time': 'Yesterday',
      'type': 'clinic',
      'unread': false,
      'icon': Icons.verified_rounded,
      'color': AppTheme.green,
    },
    {
      'id': 4,
      'title': 'Wearable Sensor Battery',
      'body': 'Inteli-Arm-V2 connected with 88% charge. IMU & EMG baseline calibrated.',
      'time': '2 days ago',
      'type': 'hardware',
      'unread': false,
      'icon': Icons.battery_charging_full_rounded,
      'color': AppTheme.navyMid,
    },
  ];

  void _markAllAsRead() {
    setState(() {
      for (var n in _notifications) {
        n['unread'] = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: const Text('Clinical Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text('Mark all read', style: TextStyle(color: AppTheme.primaryTeal, fontSize: 13)),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final n = _notifications[index];
          final bool unread = n['unread'] as bool;

          return InkWell(
            onTap: () {
              setState(() => n['unread'] = false);
              if (n['type'] == 'doctor' || n['type'] == 'reminder') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExercisePlanScreen()),
                );
              } else if (n['type'] == 'hardware') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WearableConnectionScreen()),
                );
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: unread ? Colors.white : AppTheme.slate50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: unread ? AppTheme.primaryTeal.withValues(alpha: 0.25) : AppTheme.slate200,
                  width: unread ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (n['color'] as Color).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(n['icon'] as IconData, color: n['color'] as Color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              n['title'] as String,
                              style: TextStyle(
                                fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 14,
                                color: AppTheme.slate800,
                              ),
                            ),
                            if (unread)
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryTeal,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n['body'] as String,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: unread ? AppTheme.slate600 : AppTheme.slate500,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          n['time'] as String,
                          style: const TextStyle(fontSize: 11, color: AppTheme.slate400),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
