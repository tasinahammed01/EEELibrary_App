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
}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
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
        GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: AppRoutes.explore,
          builder: (_, _) => const ExploreScreen(),
        ),
        GoRoute(
          path: AppRoutes.library,
          builder: (_, _) => const LibraryScreen(),
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
