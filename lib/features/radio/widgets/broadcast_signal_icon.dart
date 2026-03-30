import 'package:flutter/material.dart';

/// Ícone **live / rádio** para o botão «live»: [Icons.podcasts_rounded] —
/// ondas de emissão (Material), distinto de Wi‑Fi ou TV.
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
        Icons.podcasts_rounded,
        size: size,
        color: color,
      ),
    );
  }
}
