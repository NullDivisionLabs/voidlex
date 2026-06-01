import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidlex/core/app_log.dart';
import 'package:voidlex/core/server_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decodes log retention with one day as fallback', () {
    expect(AppLogRetention.decode(null), AppLogRetention.oneDay);
    expect(AppLogRetention.decode(''), AppLogRetention.oneDay);
    expect(AppLogRetention.decode('hour'), AppLogRetention.oneHour);
    expect(AppLogRetention.decode('day'), AppLogRetention.oneDay);
    expect(AppLogRetention.decode('week'), AppLogRetention.oneWeek);
    expect(AppLogRetention.decode('forever'), AppLogRetention.forever);
    expect(AppLogRetention.decode('bad-value'), AppLogRetention.oneDay);
  });

  test('persists selected log retention', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = ServerRepository(prefs);

    expect(repository.load().logRetention, AppLogRetention.oneDay);

    await repository.saveLogRetention(AppLogRetention.oneWeek);

    expect(repository.load().logRetention, AppLogRetention.oneWeek);
  });
}
