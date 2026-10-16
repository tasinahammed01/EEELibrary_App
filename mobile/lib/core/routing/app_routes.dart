abstract final class AppRoutes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const explore = '/explore';
  static const library = '/library';
  static const profile = '/profile';
  static const verification = '/verify-email';
  static const authStatus = '/auth-status';
  static const bookDetails = '/books/:slug';
  static String bookPath(String slug) => '/books/${Uri.encodeComponent(slug)}';
  static const orders = '/orders';
  static const order = '/orders/:id';
  static String orderPath(String id) => '/orders/${Uri.encodeComponent(id)}';
  static const reader = '/reader';
}
