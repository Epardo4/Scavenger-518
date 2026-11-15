import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scavenger_518/media_details_page.dart';

void main() {
  test('Netflix chip builds a search link for the title', () {
    expect(
      streamingProviderUrl(
        providerName: 'Netflix',
        title: 'Inception',
        tmdbLink: 'https://www.themoviedb.org/movie/27205/watch?locale=US',
      ),
      'https://www.netflix.com/search?q=Inception',
    );
  });

  test('an unknown service falls back to the TMDB watch page', () {
    expect(
      streamingProviderUrl(
        providerName: 'Mubi',
        title: 'Inception',
        tmdbLink: 'https://www.themoviedb.org/movie/27205/watch?locale=US',
      ),
      'https://www.themoviedb.org/movie/27205/watch?locale=US',
    );
  });

  testWidgets('tapping a streaming service opens that service page',
      (tester) async {
    String? openedName;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamingProviderChips(
            providers: const [
              {'provider_name': 'Netflix'},
            ],
            onOpen: (name) => openedName = name,
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ActionChip, 'Netflix'));
    await tester.pump();

    expect(openedName, 'Netflix');
    expect(
      streamingProviderUrl(
        providerName: openedName!,
        title: 'Inception',
        tmdbLink: null,
      ),
      'https://www.netflix.com/search?q=Inception',
    );
  });
}
