import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../helpers/auth_helper.dart';
import '../helpers/biometric_helper.dart';
import '../helpers/video_vault_service.dart';
import '../l10n/l10n.dart';

class FileEncryptionPage extends StatefulWidget {
  const FileEncryptionPage({
    super.key,
    this.service,
    this.hasSession,
    this.biometricEnabled,
    this.authenticateBiometric,
    this.verifyPassword,
  });

  final VideoVaultService? service;
  final bool Function()? hasSession;
  final Future<bool> Function()? biometricEnabled;
  final Future<bool> Function(String)? authenticateBiometric;
  final bool Function(String)? verifyPassword;

  @override
  State<FileEncryptionPage> createState() => _FileEncryptionPageState();
}

class _FileEncryptionPageState extends State<FileEncryptionPage> {
  late final VideoVaultService _service;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  final _password = TextEditingController();
  List<Map<String, dynamic>> _videos = [];
  bool _unlocked = false;
  bool _busy = false;
  bool _cancellable = false;
  bool _playing = false;
  bool _biometricEnabled = false;
  BuildContext? _deleteDialogContext;
  String? _error;
  String _phase = 'loading';
  double? _progress;
  int _generation = 0;

  bool get _hasSession =>
      (widget.hasSession ?? () => AuthHelper().isLoggedIn)();

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? VideoVaultService.instance;
    // Native full-screen UI also pauses the Flutter view. The iOS service
    // emits 'locked' only for a real background/lock event or explicit close.
    _subscription = _service.events.listen(_onEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _authenticate(useBiometric: true);
    });
  }

  void _onEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    if (event['type'] == 'locked') {
      _dismissDeleteDialog();
      _generation++;
      _password.clear();
      setState(() {
        _unlocked = false;
        _busy = false;
        _playing = false;
        _videos = [];
      });
    } else if (event['type'] == 'progress' && _busy && _unlocked) {
      setState(() {
        _phase = event['phase'] as String? ?? 'loading';
        _progress = (event['progress'] as num?)?.toDouble().clamp(0, 1);
      });
    } else if (event['type'] == 'playbackClosed') {
      setState(() => _playing = false);
    } else if (event['type'] == 'playbackFailed' ||
        event['type'] == 'cleanupFailed') {
      setState(() {
        _playing = false;
        _error = event['type'] == 'cleanupFailed'
            ? 'cleanupFailed'
            : 'invalidFile';
      });
    }
  }

  Future<void> _authenticate({bool useBiometric = false}) async {
    if (_busy) return;
    if (!_hasSession) {
      setState(() => _error = 'locked');
      return;
    }
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      bool verified = false;
      if (useBiometric) {
        final enabled =
            await (widget.biometricEnabled ??
                AuthHelper().isBiometricEnabledForCurrentUser)();
        if (!mounted || generation != _generation) return;
        setState(() => _biometricEnabled = enabled);
        if (enabled) {
          verified =
              await (widget.authenticateBiometric ??
                  (reason) => BiometricHelper().authenticate(
                    localizedReason: reason,
                  ))(context.l10n.fileEncryptionAuthReason);
        }
      } else {
        verified =
            (widget.verifyPassword ?? AuthHelper().verifyCurrentMasterPassword)(
              _password.text,
            );
        _password.clear();
        if (!verified) _error = 'password';
      }
      if (!mounted || generation != _generation || !_hasSession || !verified) {
        return;
      }
      await _service.open();
      if (!mounted || generation != _generation || !_hasSession) {
        _service.invalidate();
        return;
      }
      final videos = await _service.list();
      if (mounted && generation == _generation && _hasSession) {
        setState(() {
          _unlocked = true;
          _videos = videos;
        });
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        _service.invalidate();
        _error = error is PlatformException ? error.code : 'ioFailure';
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _operate(
    Future<void> Function() action, {
    bool imported = false,
    bool playing = false,
    bool cancellable = false,
  }) async {
    if (_busy || _playing || !_unlocked) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _cancellable = cancellable;
      _error = null;
      _progress = null;
      _phase = 'loading';
    });
    try {
      await action();
      if (!mounted || generation != _generation) return;
      if (playing) {
        setState(() => _playing = true);
      } else {
        final videos = await _service.list();
        if (!mounted || generation != _generation) return;
        setState(() => _videos = videos);
        if (imported) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.videoImported)));
        }
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        final code = error is PlatformException ? error.code : 'ioFailure';
        if (code != 'cancelled') setState(() => _error = code);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
          _cancellable = false;
        });
      }
    }
  }

  Future<void> _cancel() async {
    setState(() => _cancellable = false);
    try {
      await _service.cancel();
    } catch (_) {
      if (mounted) setState(() => _error = 'cleanupFailed');
    }
  }

  Future<void> _delete(Map<String, dynamic> video) async {
    final generation = _generation;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        _deleteDialogContext = dialogContext;
        return AlertDialog(
          title: Text(context.l10n.deleteVideo),
          content: Text(
            context.l10n.deleteVideoConfirmation(video['name'] as String),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.delete),
            ),
          ],
        );
      },
    );
    _deleteDialogContext = null;
    if (mounted && generation == _generation && confirmed == true) {
      await _operate(() => _service.delete(video['id'] as String));
    }
  }

  void _dismissDeleteDialog() {
    final dialog = _deleteDialogContext;
    _deleteDialogContext = null;
    if (dialog != null &&
        dialog.mounted &&
        ModalRoute.of(dialog)?.isCurrent == true) {
      Navigator.of(dialog).pop(false);
    }
  }

  String _errorText() {
    final l = context.l10n;
    return switch (_error) {
      'password' => l.masterPasswordIncorrect,
      'locked' => l.fileEncryptionLocked,
      'invalidFile' => l.videoInvalid,
      'insufficientSpace' => l.videoInsufficientSpace,
      'corruptFile' || 'unsupportedVersion' => l.videoCorrupt,
      'keyUnavailable' => l.videoKeyUnavailable,
      'cleanupFailed' => l.videoCleanupFailed,
      _ => l.videoOperationFailed,
    };
  }

  String get _phaseText => switch (_phase) {
    'checking' => context.l10n.videoChecking,
    'encrypting' => context.l10n.videoEncrypting,
    'decrypting' => context.l10n.videoDecrypting,
    _ => context.l10n.videoLoading,
  };

  @override
  void dispose() {
    _generation++;
    _subscription?.cancel();
    _service.invalidate();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.fileEncryption)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _errorText(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            if (!_unlocked) ...[
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 16),
              Text(l.fileEncryptionAuthReason),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: true,
                enabled: !_busy && _hasSession,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: l.masterPassword,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _authenticate(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy || !_hasSession ? null : () => _authenticate(),
                child: Text(l.unlock),
              ),
              if (_biometricEnabled)
                TextButton.icon(
                  onPressed: _busy || !_hasSession
                      ? null
                      : () => _authenticate(useBiometric: true),
                  icon: const Icon(Icons.fingerprint),
                  label: Text(l.fileEncryptionBiometric),
                ),
              if (_busy) const Center(child: CircularProgressIndicator()),
            ] else ...[
              Text(l.videoLocalOnly),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _busy || _playing
                        ? null
                        : () => _operate(
                            () => _service.importVideo('photos'),
                            imported: true,
                            cancellable: true,
                          ),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(l.videoFromPhotos),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy || _playing
                        ? null
                        : () => _operate(
                            () => _service.importVideo('files'),
                            imported: true,
                            cancellable: true,
                          ),
                    icon: const Icon(Icons.folder_open),
                    label: Text(l.videoFromFiles),
                  ),
                ],
              ),
              if (_busy)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(_phaseText),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _progress),
                      if (_cancellable)
                        TextButton(onPressed: _cancel, child: Text(l.cancel)),
                    ],
                  ),
                ),
              if (!_busy && _videos.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text(l.videoEmpty)),
                ),
              for (final video in _videos)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.video_file_outlined),
                  title: Text(
                    video['name'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${NumberFormat.decimalPattern(l.localeName).format((video['size'] as num) / (1024 * 1024))} MB\n'
                    '${DateFormat.yMd(l.localeName).add_Hm().format(DateTime.fromMillisecondsSinceEpoch((video['importedAt'] as num).toInt()))}',
                  ),
                  isThreeLine: true,
                  onTap: _busy || _playing
                      ? null
                      : () => _operate(
                          () =>
                              _service.play(video['id'] as String, l.videoDone),
                          playing: true,
                          cancellable: true,
                        ),
                  trailing: IconButton(
                    tooltip: l.deleteVideo,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _busy || _playing ? null : () => _delete(video),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
