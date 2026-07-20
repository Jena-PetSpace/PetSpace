import 'package:flutter/material.dart';

import 'search_page.dart';

/// Compatibility route. SearchPage is the single discovery/search surface.
class ExplorePage extends StatelessWidget {
  final String? initialHashtag;
  final String? initialQuery;

  const ExplorePage({
    super.key,
    this.initialHashtag,
    this.initialQuery,
  });

  @override
  Widget build(BuildContext context) {
    return SearchPage(
      initialHashtag: initialHashtag,
      initialQuery: initialQuery,
    );
  }
}
