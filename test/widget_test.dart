import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scavenger_518/main.dart';

void main() {
  testWidgets('Movie search screen is shown', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Movie Search'), findsOneWidget);
    expect(
      find.text('Search the movie database to see a title.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);
  });
}
