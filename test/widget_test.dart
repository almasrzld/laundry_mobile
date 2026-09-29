import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app/core/constants/app_strings.dart';
import 'package:laundry_app/main.dart';

void main() {
  testWidgets('LaundryApp smoke test - renders login page when not logged in', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LaundryApp(isLoggedIn: false));
    await tester.pumpAndSettle();

    // Verify login elements exist
    expect(find.text(AppStrings.appName), findsOneWidget);
  });
}
