# EEELibrary mobile

Material 3 Flutter application, with feature-first screens and go_router navigation.

Phase 2B Android authentication uses the official Firebase client SDKs and the existing backend. See [authentication setup, architecture and manual QA](docs/auth-integration.md) and [validation report](docs/phase-2b-validation.md).

```powershell
flutter pub get
flutter run -d emulator-5554 --no-enable-impeller
```

Debug backend URL defaults to the Android emulator host, `http://10.0.2.2:3000`. Override it using `--dart-define=BACKEND_BASE_URL=...`. Profile/release requires a trusted HTTPS URL. The Impeller workaround applies only to this local emulator invocation.

Android Firebase client configuration is in `android/app/google-services.json`. Never place Firebase Admin credentials in this app. Non-Android Firebase setup, production signing/deployment, payments, paid access and PDF authorization remain outside the implemented phase.

Validation:

```powershell
dart format .
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```
