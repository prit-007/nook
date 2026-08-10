import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';

class EmptyHome extends StatelessWidget {
  const EmptyHome({super.key, this.animate = true});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.auto_awesome_rounded,
      title: 'Your canvas is clear',
      subtitle: 'Tap "New Note" below to capture a thought or sketch.',
      animate: animate,
    );
  }
}
