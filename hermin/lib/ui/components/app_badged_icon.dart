import 'package:flutter/material.dart';

class AppBadgedIcon extends StatelessWidget {
  const AppBadgedIcon({super.key, required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Badge(label: Text('$count'), isLabelVisible: count > 0, child: Icon(icon));
  }
}
