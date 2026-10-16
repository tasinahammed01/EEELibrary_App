class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.slug,
    required this.name,
  });
  final String id, slug, name;
  factory CatalogCategory.fromJson(Map<String, dynamic> json) =>
      CatalogCategory(
        id: _text(json, 'id'),
        slug: _text(json, 'slug'),
        name: _text(json, 'name'),
      );
}

String _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Invalid catalog response');
  }
  return value;
}

class CatalogBook {
  const CatalogBook({
    required this.slug,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.currency,
    this.pageCount,
  });
  final String slug, title, description, price, currency;
  final CatalogCategory category;
  final int? pageCount;
  String get priceLabel =>
      double.parse(price) == 0 ? 'Free' : '$currency $price';
  factory CatalogBook.fromJson(
    Map<String, dynamic> json, {
    bool details = false,
  }) {
    final price = _text(json, 'price');
    final amount = double.tryParse(price);
    final pages = json['pageCount'];
    if (amount == null ||
        !amount.isFinite ||
        amount < 0 ||
        (pages != null && (pages is! int || pages < 0))) {
      throw const FormatException('Invalid catalog response');
    }
    return CatalogBook(
      slug: _text(json, 'slug'),
      title: _text(json, 'title'),
      description: details ? _text(json, 'description') : '',
      category: CatalogCategory.fromJson(
        json['category'] as Map<String, dynamic>,
      ),
      price: price,
      currency: _text(json, 'currency'),
      pageCount: pages as int?,
    );
  }
}

class CatalogPage {
  const CatalogPage({
    required this.items,
    required this.page,
    required this.total,
    required this.hasMore,
  });
  final List<CatalogBook> items;
  final int page, total;
  final bool hasMore;
  factory CatalogPage.fromJson(Map<String, dynamic> json) {
    final page = json['page'], total = json['total'], more = json['hasMore'];
    final items = json['items'];
    if (page is! int ||
        page < 1 ||
        total is! int ||
        total < 0 ||
        more is! bool ||
        items is! List ||
        items.length > 40) {
      throw const FormatException('Invalid catalog response');
    }
    return CatalogPage(
      items: List.unmodifiable(
        items.map((e) => CatalogBook.fromJson(e as Map<String, dynamic>)),
      ),
      page: page,
      total: total,
      hasMore: more,
    );
  }
}

class CatalogFailure implements Exception {
  const CatalogFailure({this.notFound = false});
  final bool notFound;
  String get message => notFound
      ? 'This book is not available.'
      : "We couldn't load the catalog. Check your connection and try again.";
}
