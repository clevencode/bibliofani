import 'package:flutter/material.dart';

/// Ícone **live** para o botão «live»: [Icons.sensors] (Material / Google).
class BroadcastSignalIcon extends StatelessWidget {
  const BroadcastSignalIcon({
    super.key,
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      excludeSemantics: true,
      child: Icon(
        Icons.sensors,
        size: size,
        color: color,
      ),
    );
  }
}
