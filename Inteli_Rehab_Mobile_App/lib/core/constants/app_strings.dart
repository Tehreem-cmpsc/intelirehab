import 'package:flutter/material.dart';

class CategoryItem {
  final String name;
  final IconData icon;
  const CategoryItem(this.name, this.icon);
}

class AppConstants {
  static const List<CategoryItem> categories = [
    CategoryItem('All', Icons.grid_view_rounded),
    CategoryItem('Shoulder', Icons.accessibility_new_rounded),
    CategoryItem('Elbow', Icons.gesture_rounded),
    CategoryItem('Wrist', Icons.pan_tool_alt_rounded),
    CategoryItem('Stretching', Icons.airline_seat_recline_normal_rounded),
    CategoryItem('Strength', Icons.fitness_center_rounded),
  ];

  static const List<String> motivationalMessages = [
    "Every movement brings you closer to recovery.",
    "Stay consistent. Progress loves patience.",
    "You're doing great — keep showing up.",
    "Small progress is still progress.",
    "Recovery isn't linear, but you are moving forward.",
    "One session at a time. You've got this.",
  ];

  static const List<Map<String, String>> notifications = [
    {
      'title': 'Exercise Reminder',
      'subtitle': "Don't forget your Wrist Supination session today.",
      'time': '10 min ago',
      'icon': 'reminder',
    },
    {
      'title': 'New Exercise Assigned',
      'subtitle': 'Dr. Sarah Jenkins added a new stretching routine.',
      'time': '1 hr ago',
      'icon': 'assigned',
    },
    {
      'title': 'Recovery Improved',
      'subtitle': 'Your recovery score improved by 5% this week!',
      'time': '3 hrs ago',
      'icon': 'improved',
    },
    {
      'title': 'Wearable Battery Low',
      'subtitle': 'Your wearable is at 15%. Please charge soon.',
      'time': 'Yesterday',
      'icon': 'battery',
    },
  ];

  static const Map<String, String> wearableInfo = {
    'battery': '87%',
    'lastSync': '2 minutes ago',
    'firmware': 'v2.4.1',
    'bluetooth': 'Connected',
    'strength': 'Excellent',
    'connectionId': 'IR-WB-7743-XT',
  };
}
