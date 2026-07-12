import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app/Features/Profile/profile_page.dart';
import 'package:travel_app/Features/Wallet/wallet_page.dart';

void main() {
  Widget wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

  group('Supplementary Core Screens Widget Tests', () {
    testWidgets('WalletPage tracking dashboard layout check', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const WalletPage()));
      await tester.pump();
      expect(find.textContaining('Trips'), findsOneWidget);
    });

    testWidgets('ProfilePage preferences panel toggle check', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const ProfilePage()));
      await tester.pump();
      expect(find.byType(Switch), findsOneWidget);
    });
  });
}