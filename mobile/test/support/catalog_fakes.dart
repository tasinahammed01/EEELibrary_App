import 'package:eeelibrary/features/catalog/data/catalog_repository.dart';
import 'package:eeelibrary/features/catalog/domain/catalog_models.dart';

const fixtureCategories = [
  CatalogCategory(id: 'circuit', slug: 'circuit', name: 'Circuit Theory'),
  CatalogCategory(id: 'power', slug: 'power', name: 'Power Systems'),
];
final fixtureBooks = List.generate(
  4,
  (i) => CatalogBook(
    slug: 'study-guide-$i',
    title: i == 0
        ? 'Electrical Circuit Analysis'
        : 'Engineering study guide $i with a long readable title',
    description: 'A development resource description.',
    category: fixtureCategories[i % 2],
    price: i == 0 ? '0.00' : '320.00',
    currency: 'BDT',
    pageCount: 120,
  ),
);

class FakeCatalog implements CatalogRepository {
  Future<List<CatalogCategory>> Function()? categoriesHandler;
  Future<CatalogPage> Function(
    int page,
    String search,
    String? category,
    String sort,
  )?
  booksHandler;
  Future<CatalogBook> Function(String slug)? bookHandler;
  int requests = 0;
  String search = '', sort = '';
  String? category;
  @override
  Future<List<CatalogCategory>> categories() async =>
      categoriesHandler == null ? fixtureCategories : categoriesHandler!();
  @override
  Future<CatalogPage> books({
    int page = 1,
    int pageSize = 12,
    String search = '',
    String? category,
    String sort = 'newest',
  }) async {
    requests++;
    this.search = search;
    this.category = category;
    this.sort = sort;
    return booksHandler == null
        ? CatalogPage(items: fixtureBooks, page: page, total: 4, hasMore: false)
        : booksHandler!(page, search, category, sort);
  }

  @override
  Future<CatalogBook> book(String slug) async => bookHandler == null
      ? fixtureBooks.firstWhere((b) => b.slug == slug)
      : bookHandler!(slug);
  @override
  void close() {}
}
