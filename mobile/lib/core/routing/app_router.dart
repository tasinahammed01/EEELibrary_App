import '../../features/purchases/data/purchase_repository.dart';
import '../../features/purchases/presentation/order_screen.dart';
import '../../features/catalog/book_details_screen.dart';
import '../../features/catalog/data/catalog_repository.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/verification_screen.dart';
import '../../features/auth/auth_status_screen.dart';

import 'package:go_router/go_router.dart';

import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/welcome_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/explore/explore_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/reader/secure_reader_screen.dart';
import '../widgets/main_shell.dart';
import 'app_routes.dart';

final appRouter = createAppRouter();
GoRouter createAppRouter({
  String initialLocation = AppRoutes.splash,
  AuthController? auth,
  CatalogRepository? catalog,
  PurchaseRepository? purchases,
}) => GoRouter(
  initialLocation: initialLocation,
  refreshListenable: auth,
  redirect: (context, state) {
    if (auth == null) return null;
    final location = state.uri.path;
    if (location == AppRoutes.splash && !auth.splashReady) return null;
    final target = switch (auth.status) {
      AuthStatus.initializing => AppRoutes.splash,
      AuthStatus.verificationRequired => AppRoutes.verification,
      AuthStatus.error => AppRoutes.authStatus,
      AuthStatus.authenticated =>
        {
              AppRoutes.splash,
              AppRoutes.welcome,
              AppRoutes.login,
              AppRoutes.register,
              AppRoutes.verification,
              AppRoutes.authStatus,
            }.contains(location)
            ? AppRoutes.home
            : location,
      AuthStatus.signedOut =>
        {
              AppRoutes.splash,
              AppRoutes.verification,
              AppRoutes.authStatus,
            }.contains(location)
            ? (auth.message == null ? AppRoutes.welcome : AppRoutes.login)
            : (location == AppRoutes.reader ||
                  location == AppRoutes.orders ||
                  location.startsWith('${AppRoutes.orders}/'))
            ? AppRoutes.login
            : location,
    };
    return target == location ? null : target;
  },
  routes: [
    GoRoute(
      path: AppRoutes.orders,
      builder: (_, _) => OrdersScreen(repository: purchases),
    ),
    GoRoute(
      path: AppRoutes.order,
      builder: (_, state) =>
          OrderScreen(id: state.pathParameters['id']!, repository: purchases),
    ),
    GoRoute(
      path: AppRoutes.bookDetails,
      builder: (_, state) => BookDetailsScreen(
        slug: state.pathParameters['slug']!,
        repository: catalog,
        purchases: purchases,
      ),
    ),
    GoRoute(
      path: AppRoutes.verification,
      builder: (_, _) => const VerificationScreen(),
    ),
    GoRoute(
      path: AppRoutes.authStatus,
      builder: (_, _) => const AuthStatusScreen(),
    ),
    GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
    GoRoute(path: AppRoutes.welcome, builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
    GoRoute(
      path: AppRoutes.register,
      builder: (_, _) => const RegisterScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) =>
          MainShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (_, _) => HomeScreen(repository: catalog),
        ),
        GoRoute(
          path: AppRoutes.explore,
          builder: (_, state) => ExploreScreen(
            repository: catalog,
            initialCategory: state.uri.queryParameters['category'],
          ),
        ),
        GoRoute(
          path: AppRoutes.library,
          builder: (_, _) => LibraryScreen(repository: purchases),
        ),
        GoRoute(
          path: AppRoutes.profile,
          builder: (_, _) => const ProfileScreen(),
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.reader,
      builder: (_, _) => const SecureReaderScreen(),
    ),
  ],
);
