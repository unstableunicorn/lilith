// Where "find nearby" and "buy online" send the browser for something to buy.

/// A maps search for [item] near the user.
Uri mapsNearMe(String item) => Uri(
  scheme: 'https',
  host: 'www.google.com',
  pathSegments: ['maps', 'search', '$item near me'],
);

/// A shopping search for [item].
Uri retailerSearch(String item) =>
    Uri.https('www.google.com', '/search', {'q': 'buy $item', 'tbm': 'shop'});
