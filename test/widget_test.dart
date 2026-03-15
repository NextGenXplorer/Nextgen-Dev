import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_ai_ide/ui/screens/onboarding_screen.dart';

void main() {
  testWidgets('Onboarding screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );

    // Verify that onboarding text is present
    expect(find.text('Security First IDE'), findsOneWidget);
    expect(find.text('Primary Provider'), findsOneWidget);

    // Verify that 'Local' is the first option in the dropdown essentially
    // We can't easily check dropdown items without opening it, but we can check if the button is there.
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

    // Check for the "Start Private Session" button
    expect(find.text('Start Private Session'), findsOneWidget);
  });
}
