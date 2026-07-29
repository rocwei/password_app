import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/otp_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'otp_token_ids': jsonEncode(['legacy-1']),
      'otp_token_legacy-1': jsonEncode({
        'id': 'legacy-1',
        'label': 'Legacy',
        'secret': 'old-secret',
      }),
    });
  });

  test('reads legacy tokens when no atomic blob exists', () async {
    final tokens = await OtpHelper.getAllTokensOrThrow();

    expect(tokens, hasLength(1));
    expect(tokens.single.id, 'legacy-1');
    expect(tokens.single.secret, 'old-secret');
  });

  test('atomic replacement can restore the exact legacy snapshot', () async {
    const storage = FlutterSecureStorage();
    final snapshot = await OtpHelper.captureSnapshotOrThrow();

    await OtpHelper.replaceAllTokensOrThrow([
      OtpToken(id: 'new-1', label: 'New', secret: 'new-secret'),
      OtpToken(id: 'new-2', label: 'New 2', secret: 'new-secret-2'),
    ]);

    expect((await OtpHelper.getAllTokensOrThrow()).map((token) => token.id), [
      'new-1',
      'new-2',
    ]);
    expect(await storage.read(key: 'otp_tokens_v2'), isNotNull);

    await OtpHelper.restoreSnapshotOrThrow(snapshot);

    final restored = await OtpHelper.getAllTokensOrThrow();
    expect(restored, hasLength(1));
    expect(restored.single.id, 'legacy-1');
    expect(restored.single.secret, 'old-secret');
    expect(await storage.read(key: 'otp_tokens_v2'), isNull);
  });
}
