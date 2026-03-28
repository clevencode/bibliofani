import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_app/app/app.dart';
import 'package:meu_app/features/radio/screens/radio_player_page.dart';

void main() {
  testWidgets('App inicia e exibe o botão de play', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: RadioApp(home: RadioPlayerPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });
}
