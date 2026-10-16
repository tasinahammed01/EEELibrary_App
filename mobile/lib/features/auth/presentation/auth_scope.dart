import 'package:flutter/widgets.dart';

import 'auth_controller.dart';

class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController controller,
    required super.child,
  }) : super(notifier: controller);
  static AuthController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()?.notifier;
  static AuthController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AuthScope>()?.notifier;
}
