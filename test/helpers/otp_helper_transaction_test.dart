import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/otp_helper.dart';

const _journalKey = 'otp_storage_transaction';
const _indexKey = 'otp_token_ids';

void main() {
  late _FakeOtpStorageBackend backend;

  setUp(() {
    backend = _FakeOtpStorageBackend();
    OtpHelper.setStorageBackendForTesting(backend);
  });

  tearDown(OtpHelper.resetStorageBackendForTesting);

  Matcher isStorageFailure(
    OtpStorageOperation operation, {
    bool? recoveryPending,
  }) {
    var matcher = isA<OtpStorageException>().having(
      (error) => error.operation,
      'operation',
      operation,
    );
    if (recoveryPending != null) {
      matcher = matcher.having(
        (error) => error.recoveryPending,
        'recoveryPending',
        recoveryPending,
      );
    }
    return matcher;
  }

  test('empty labels remain valid stored user data', () async {
    final token = OtpToken.fromJson({
      'id': 'empty-label',
      'label': '',
      'secret': 'JBSWY3DPEHPK3PXP',
    });

    await OtpHelper.importTokens([token.toJson()]);

    final loaded = await OtpHelper.getAllTokens();
    expect(loaded.single.label, '');
    expect(backend.values['otp_token_empty-label'], jsonEncode(token.toJson()));
  });

  test(
    'concurrent saves are strictly serialized without losing tokens',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      backend.holdWriteOnCall(_journalKey, 1, entered, release);

      final first = OtpHelper.saveToken(
        OtpToken(id: 'first', label: 'First', secret: 'JBSWY3DPEHPK3PXP'),
      );
      await entered.future;
      final second = OtpHelper.saveToken(
        OtpToken(id: 'second', label: 'Second', secret: 'KRUGS4ZANFZSAYJA'),
      );

      try {
        await Future<void>.delayed(Duration.zero);
        expect(backend.writeCallCount(_journalKey), 1);
      } finally {
        release.complete();
      }
      await Future.wait([first, second]);

      expect((await OtpHelper.getAllTokens()).map((token) => token.id), [
        'first',
        'second',
      ]);
      expect(backend.values, isNot(contains(_journalKey)));
      _expectNoDanglingIndex(backend);
    },
  );

  test('concurrent save and import run in call order', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    backend.holdWriteOnCall(_journalKey, 1, entered, release);

    final save = OtpHelper.saveToken(
      OtpToken(id: 'saved', label: 'Saved', secret: 'JBSWY3DPEHPK3PXP'),
    );
    await entered.future;
    final import = OtpHelper.importTokens([
      {'id': 'imported', 'label': 'Imported', 'secret': 'KRUGS4ZANFZSAYJA'},
    ]);

    try {
      await Future<void>.delayed(Duration.zero);
      expect(backend.writeCallCount(_journalKey), 1);
    } finally {
      release.complete();
    }
    await Future.wait([save, import]);

    expect((await OtpHelper.getAllTokens()).map((token) => token.id), [
      'imported',
    ]);
    expect(backend.values, isNot(contains('otp_token_saved')));
    expect(backend.values, isNot(contains(_journalKey)));
    _expectNoDanglingIndex(backend);
  });

  test('export waits behind an active mutation and reads its result', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    backend.holdWriteOnCall(_journalKey, 1, entered, release);

    final save = OtpHelper.saveToken(
      OtpToken(id: 'saved', label: 'Saved', secret: 'JBSWY3DPEHPK3PXP'),
    );
    await entered.future;
    final export = OtpHelper.exportTokens();

    try {
      await Future<void>.delayed(Duration.zero);
      expect(backend.readCallCount(_journalKey), 1);
      expect(backend.readCallCount(_indexKey), 1);
    } finally {
      release.complete();
    }

    await save;
    expect((await export).map((token) => token['id']), ['saved']);
    expect(backend.values, isNot(contains(_journalKey)));
    _expectNoDanglingIndex(backend);
  });

  test('a failed queued operation does not poison later operations', () async {
    backend.failWriteOnCall(_journalKey, 1);

    final failed = OtpHelper.saveToken(
      OtpToken(id: 'failed', label: 'Failed', secret: 'JBSWY3DPEHPK3PXP'),
    );
    final succeeds = OtpHelper.saveToken(
      OtpToken(id: 'saved', label: 'Saved', secret: 'KRUGS4ZANFZSAYJA'),
    );

    await expectLater(
      failed,
      throwsA(isStorageFailure(OtpStorageOperation.save)),
    );
    await succeeds;

    expect((await OtpHelper.getAllTokens()).map((token) => token.id), [
      'saved',
    ]);
    expect(backend.values, isNot(contains(_journalKey)));
    _expectNoDanglingIndex(backend);
  });

  test(
    'failure before journal creation leaves the before snapshot intact',
    () async {
      backend.values.addAll(_storedToken('old', 'Old', 'JBSWY3DPEHPK3PXP'));
      final before = Map<String, String>.of(backend.values);
      backend.failWriteOnCall(_journalKey, 1);

      await expectLater(
        OtpHelper.saveToken(_newToken()),
        throwsA(isStorageFailure(OtpStorageOperation.save)),
      );

      expect(backend.values, before);
      _expectNoDanglingIndex(backend);
    },
  );

  test('prewrite interruption recovers the complete before snapshot', () async {
    backend.values.addAll(_storedToken('old', 'Old', 'JBSWY3DPEHPK3PXP'));
    backend.failWriteOnCall('otp_token_new', 1);

    await expectLater(
      OtpHelper.saveToken(_newToken()),
      throwsA(isStorageFailure(OtpStorageOperation.save)),
    );

    expect(await OtpHelper.getAllTokens(), hasLength(1));
    expect((await OtpHelper.getAllTokens()).single.id, 'old');
    expect(backend.values, isNot(contains(_journalKey)));
    _expectNoDanglingIndex(backend);
  });

  test(
    'commit-intent write interruption recovers before and removes prewrites',
    () async {
      backend.values.addAll(_storedToken('old', 'Old', 'JBSWY3DPEHPK3PXP'));
      backend.failWriteOnCall(_journalKey, 2);

      await expectLater(
        OtpHelper.saveToken(_newToken()),
        throwsA(isStorageFailure(OtpStorageOperation.save)),
      );

      final loaded = await OtpHelper.getAllTokens();
      expect(loaded.map((token) => token.id), ['old']);
      expect(backend.values, isNot(contains('otp_token_new')));
      expect(backend.values, isNot(contains(_journalKey)));
      _expectNoDanglingIndex(backend);
    },
  );

  test(
    'after-index interruption commits the complete after snapshot',
    () async {
      backend.values.addAll(_storedToken('old', 'Old', 'JBSWY3DPEHPK3PXP'));
      backend.failWriteOnCall(_indexKey, 1);

      await OtpHelper.saveToken(_newToken());

      final loaded = await OtpHelper.getAllTokens();
      expect(loaded.map((token) => token.id), ['old', 'new']);
      expect(backend.values, isNot(contains(_journalKey)));
      _expectNoDanglingIndex(backend);
    },
  );

  test(
    'cleanup interruption commits delete without a dangling index',
    () async {
      backend.values.addAll(_storedToken('old', 'Old', 'JBSWY3DPEHPK3PXP'));
      backend.failDeleteOnCall('otp_token_old', 1);

      await OtpHelper.deleteToken('old');

      expect(await OtpHelper.getAllTokens(), isEmpty);
      expect(backend.values, isNot(contains('otp_token_old')));
      expect(backend.values, isNot(contains(_journalKey)));
      _expectNoDanglingIndex(backend);
    },
  );

  test(
    'journal cleanup interruption is idempotently completed as after',
    () async {
      backend.values.addAll(_storedToken('old', 'Old', 'JBSWY3DPEHPK3PXP'));
      backend.failDeleteOnCall(_journalKey, 1);

      await OtpHelper.saveToken(_newToken());

      expect((await OtpHelper.getAllTokens()).map((token) => token.id), [
        'old',
        'new',
      ]);
      expect(backend.values, isNot(contains(_journalKey)));
      _expectNoDanglingIndex(backend);
    },
  );

  test(
    'failed before recovery keeps journal and a later load retries it',
    () async {
      backend.values.addAll(_storedToken('old', 'Old', 'JBSWY3DPEHPK3PXP'));
      backend.failWriteOnCall('otp_token_new', 1);
      backend.failWriteOnCall('otp_token_old', 2);

      await expectLater(
        OtpHelper.saveToken(_newToken()),
        throwsA(
          isStorageFailure(OtpStorageOperation.save, recoveryPending: true),
        ),
      );

      expect(_journalRecovery(backend), 'before');
      _expectNoDanglingIndex(backend);

      final loaded = await OtpHelper.getAllTokens();
      expect(loaded.map((token) => token.id), ['old']);
      expect(backend.values, isNot(contains(_journalKey)));
      _expectNoDanglingIndex(backend);
    },
  );

  test(
    'failed after recovery returns save success and later load commits once',
    () async {
      backend.failWriteOnCall(_indexKey, 1);
      backend.failWriteOnCall(_indexKey, 2);

      await OtpHelper.saveToken(_newToken());

      expect(_journalRecovery(backend), 'after');
      _expectNoDanglingIndex(backend);

      final loaded = await OtpHelper.getAllTokens();
      expect(loaded.map((token) => token.id), ['new']);
      expect(backend.values, isNot(contains(_journalKey)));
      _expectNoDanglingIndex(backend);
    },
  );

  test(
    'before-pending retry with the same id stores exactly one token',
    () async {
      final token = OtpToken(
        id: 'same',
        label: 'Same',
        secret: 'JBSWY3DPEHPK3PXP',
      );
      backend.failWriteOnCall('otp_token_same', 1);
      backend.failDeleteOnCall(_indexKey, 1);

      await expectLater(
        OtpHelper.saveToken(token),
        throwsA(
          isStorageFailure(OtpStorageOperation.save, recoveryPending: true),
        ),
      );
      expect(_journalRecovery(backend), 'before');

      await OtpHelper.saveToken(token);

      final loaded = await OtpHelper.getAllTokens();
      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'same');
      expect((jsonDecode(backend.values[_indexKey]!) as List<dynamic>), [
        'same',
      ]);
      expect(backend.values, isNot(contains(_journalKey)));
      _expectNoDanglingIndex(backend);
    },
  );

  test(
    'import prewrite failure restores before without mixed records',
    () async {
      backend.values.addAll(_storedToken('old', 'Old / 原样', 'RAWBASE32VALUE'));
      backend.failWriteOnCall('otp_token_new-two', 1);

      await expectLater(
        OtpHelper.importTokens([
          {'id': 'new-one', 'label': 'New One', 'secret': 'JBSWY3DPEHPK3PXP'},
          {'id': 'new-two', 'label': 'New Two', 'secret': 'KRUGS4ZANFZSAYJA'},
        ]),
        throwsA(isStorageFailure(OtpStorageOperation.importTokens)),
      );

      final loaded = await OtpHelper.getAllTokens();
      expect(loaded.map((token) => token.id), ['old']);
      expect(loaded.single.label, 'Old / 原样');
      expect(loaded.single.secret, 'RAWBASE32VALUE');
      expect(backend.values.keys, isNot(contains('otp_token_new-one')));
      _expectNoDanglingIndex(backend);
    },
  );

  test(
    'failed after recovery returns import success and later load commits once',
    () async {
      backend.values.addAll(_storedToken('old', 'Old', 'JBSWY3DPEHPK3PXP'));
      backend.failWriteOnCall(_indexKey, 1);
      backend.failWriteOnCall(_indexKey, 2);

      await OtpHelper.importTokens([
        {'id': 'target', 'label': 'Target', 'secret': 'KRUGS4ZANFZSAYJA'},
      ]);

      expect(_journalRecovery(backend), 'after');
      _expectNoDanglingIndex(backend);

      expect((await OtpHelper.getAllTokens()).map((token) => token.id), [
        'target',
      ]);
      expect(backend.values, isNot(contains('otp_token_old')));
      expect(backend.values, isNot(contains(_journalKey)));
      _expectNoDanglingIndex(backend);
    },
  );

  test(
    'clear recovery failure keeps after journal for the next load',
    () async {
      backend.values.addAll(
        _storedTokens([
          OtpToken(id: 'one', label: 'One', secret: 'JBSWY3DPEHPK3PXP'),
          OtpToken(id: 'two', label: 'Two', secret: 'KRUGS4ZANFZSAYJA'),
        ]),
      );
      backend.failDeleteOnCall('otp_token_one', 1);
      backend.failDeleteOnCall('otp_token_one', 2);

      await OtpHelper.clearAllTokens();

      expect(_journalRecovery(backend), 'after');
      _expectNoDanglingIndex(backend);
      expect(await OtpHelper.getAllTokens(), isEmpty);
      expect(backend.values, isNot(contains(_journalKey)));
      _expectNoDanglingIndex(backend);
    },
  );

  test(
    'invalid import is rejected before transaction data is written',
    () async {
      backend.values.addAll(_storedToken('old', 'Old', 'JBSWY3DPEHPK3PXP'));
      final before = Map<String, String>.of(backend.values);

      await expectLater(
        OtpHelper.importTokens([
          {'id': 'valid', 'label': 'Valid', 'secret': 'KRUGS4ZANFZSAYJA'},
          {'id': 'invalid', 'label': 'Invalid'},
        ]),
        throwsA(isStorageFailure(OtpStorageOperation.importTokens)),
      );

      expect(backend.values, before);
    },
  );
}

OtpToken _newToken() {
  return OtpToken(id: 'new', label: 'New / 原样', secret: 'KRUGS4ZANFZSAYJA');
}

String? _journalRecovery(_FakeOtpStorageBackend backend) {
  final journal = backend.values[_journalKey];
  if (journal == null) return null;
  return (jsonDecode(journal) as Map<String, dynamic>)['recovery'] as String?;
}

void _expectNoDanglingIndex(_FakeOtpStorageBackend backend) {
  final index = backend.values[_indexKey];
  if (index == null || index.isEmpty) return;
  final ids = (jsonDecode(index) as List<dynamic>).cast<String>();
  for (final id in ids) {
    expect(
      backend.values['otp_token_$id'],
      isNotNull,
      reason: 'index references missing token $id',
    );
  }
}

Map<String, String> _storedToken(String id, String label, String secret) {
  return _storedTokens([OtpToken(id: id, label: label, secret: secret)]);
}

Map<String, String> _storedTokens(List<OtpToken> tokens) {
  return {
    _indexKey: jsonEncode(tokens.map((token) => token.id).toList()),
    for (final token in tokens)
      'otp_token_${token.id}': jsonEncode(token.toJson()),
  };
}

class _FakeOtpStorageBackend implements OtpStorageBackend {
  final values = <String, String>{};
  final _readCalls = <String, int>{};
  final _writeCalls = <String, int>{};
  final _deleteCalls = <String, int>{};
  final _writeFailures = <String, Set<int>>{};
  final _deleteFailures = <String, Set<int>>{};
  final _writeHolds = <String, Map<int, _BackendHold>>{};

  void failWriteOnCall(String key, int call) {
    (_writeFailures[key] ??= <int>{}).add(call);
  }

  void failDeleteOnCall(String key, int call) {
    (_deleteFailures[key] ??= <int>{}).add(call);
  }

  void holdWriteOnCall(
    String key,
    int call,
    Completer<void> entered,
    Completer<void> release,
  ) {
    (_writeHolds[key] ??= <int, _BackendHold>{})[call] = _BackendHold(
      entered,
      release,
    );
  }

  int writeCallCount(String key) => _writeCalls[key] ?? 0;

  int readCallCount(String key) => _readCalls[key] ?? 0;

  @override
  Future<String?> read({required String key}) async {
    _readCalls[key] = (_readCalls[key] ?? 0) + 1;
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    final call = (_writeCalls[key] ?? 0) + 1;
    _writeCalls[key] = call;
    if (_writeFailures[key]?.remove(call) ?? false) {
      throw StateError('controlled write failure');
    }
    final hold = _writeHolds[key]?.remove(call);
    if (hold != null) {
      hold.entered.complete();
      await hold.release.future;
    }
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    final call = (_deleteCalls[key] ?? 0) + 1;
    _deleteCalls[key] = call;
    if (_deleteFailures[key]?.remove(call) ?? false) {
      throw StateError('controlled delete failure');
    }
    values.remove(key);
  }
}

class _BackendHold {
  const _BackendHold(this.entered, this.release);

  final Completer<void> entered;
  final Completer<void> release;
}
