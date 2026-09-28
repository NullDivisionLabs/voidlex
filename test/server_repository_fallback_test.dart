import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voidlex/core/models/server_config.dart';
import 'package:voidlex/core/models/server_subscription.dart';
import 'package:voidlex/core/secure_storage.dart';
import 'package:voidlex/core/server_repository.dart';

class FakeSecureStorage extends SecureStorage {
  final Map<String, String> data = {};
  bool failWrite = false;
  bool failRemove = false;

  @override
  Future<String?> readString(String key) async => data[key];

  @override
  Future<void> writeString(String key, String value) async {
    if (failWrite) {
      throw const SecureStorageException(
        SecureStorageError.writeFailed,
        'simulated write failure',
      );
    }
    data[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    if (failRemove) {
      throw const SecureStorageException(
        SecureStorageError.writeFailed,
        'simulated remove failure',
      );
    }
    data.remove(key);
  }
}

ServerConfig _server(String name) {
  return ServerConfig(
    name: name,
    address: '${name.toLowerCase()}.example.com',
    port: 443,
    uuid: '00000000-0000-0000-0000-000000000000',
    transport: VlessTransport.tcp,
    security: VlessSecurity.none,
  );
}

ServerSubscription _subscription(String id, String name) {
  return ServerSubscription(
    id: id,
    name: name,
    url: 'https://$id.example.com/sub',
    servers: [_server('$name-node')],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deleted server does not resurrect when secure storage write fails', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final secure = FakeSecureStorage();

    final repo1 = ServerRepository(prefs, secureStorage: secure);
    await repo1.init();

    // 1. Initial save of two servers succeeds to secure storage
    await repo1.saveServers([_server('Alpha'), _server('Beta')]);
    expect(repo1.load().servers.map((s) => s.name).toList(), ['Alpha', 'Beta']);
    expect(secure.data['void.servers'], isNotNull);
    expect(prefs.containsKey('void.servers'), isFalse);

    // 2. Turn on secure write failure, delete 'Beta'
    secure.failWrite = true;
    await repo1.saveServers([_server('Alpha')]);

    // Memory cache and fallback prefs reflect only 'Alpha'
    expect(repo1.load().servers.map((s) => s.name).toList(), ['Alpha']);
    expect(prefs.containsKey('void.servers'), isTrue);

    // 3. New repository instance initialized (app restart)
    final repo2 = ServerRepository(prefs, secureStorage: secure);
    await repo2.init();

    // 'Beta' must NOT resurrect
    final loadedNames = repo2.load().servers.map((s) => s.name).toList();
    expect(loadedNames, ['Alpha']);
  });

  test('deleted server does not resurrect even if secure remove also fails', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final secure = FakeSecureStorage();

    final repo1 = ServerRepository(prefs, secureStorage: secure);
    await repo1.init();

    await repo1.saveServers([_server('Alpha'), _server('Beta')]);

    // Both write and remove fail on secure storage, leaving stale data in secure
    secure.failWrite = true;
    secure.failRemove = true;
    await repo1.saveServers([_server('Alpha')]);

    // Stale data remains in secure map, but prefs contains fallback
    expect(secure.data['void.servers'], contains('Beta'));
    expect(prefs.containsKey('void.servers'), isTrue);

    // Re-init repo with stale secure data present
    final repo2 = ServerRepository(prefs, secureStorage: secure);
    await repo2.init();

    // Prefs fallback must take precedence over stale secure data
    final loadedNames = repo2.load().servers.map((s) => s.name).toList();
    expect(loadedNames, ['Alpha']);
  });

  test('deleted subscription does not resurrect when secure storage write fails', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final secure = FakeSecureStorage();

    final repo1 = ServerRepository(prefs, secureStorage: secure);
    await repo1.init();

    await repo1.saveSubscriptions([
      _subscription('s1', 'Sub1'),
      _subscription('s2', 'Sub2'),
    ]);
    expect(repo1.load().subscriptions.map((s) => s.name).toList(), ['Sub1', 'Sub2']);

    secure.failWrite = true;
    await repo1.saveSubscriptions([_subscription('s1', 'Sub1')]);

    final repo2 = ServerRepository(prefs, secureStorage: secure);
    await repo2.init();

    expect(repo2.load().subscriptions.map((s) => s.name).toList(), ['Sub1']);
  });
}
