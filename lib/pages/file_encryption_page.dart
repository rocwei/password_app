import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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
  BuildContext? _importSheetContext;
  String? _error;
  String _phase = 'loading';
  double? _progress;
  int _generation = 0;

  bool get _hasSession =>
      (widget.hasSession ?? () => AuthHelper().isLoggedIn)();

  bool get _canOperate => _unlocked && !_busy && !_playing && _hasSession;

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
      _dismissImportSheet();
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
    if (!_canOperate) return;
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
    if (!_canOperate) return;
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

  void _dismissImportSheet() {
    final sheet = _importSheetContext;
    _importSheetContext = null;
    if (sheet != null &&
        sheet.mounted &&
        ModalRoute.of(sheet)?.isCurrent == true) {
      Navigator.of(sheet).pop();
    }
  }

  Future<void> _showImportOptions() async {
    if (!_canOperate || _importSheetContext != null) return;
    final generation = _generation;
    final l = context.l10n;
    final source = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        _importSheetContext = sheetContext;
        void select(String? value) {
          if (mounted &&
              generation == _generation &&
              _canOperate &&
              sheetContext.mounted &&
              ModalRoute.of(sheetContext)?.isCurrent == true) {
            Navigator.pop(sheetContext, value);
          }
        }

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Text(
                    l.videoSupportedFormats,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(l.videoFromPhotos),
                  onTap: () => select('photos'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.folder_open_outlined),
                  title: Text(l.videoFromFiles),
                  onTap: () => select('files'),
                ),
                const Divider(height: 12, thickness: 8),
                ListTile(
                  title: Text(l.cancel, textAlign: TextAlign.center),
                  onTap: () => select(null),
                ),
              ],
            ),
          ),
        );
      },
    );
    _importSheetContext = null;
    if (!mounted ||
        generation != _generation ||
        !_canOperate ||
        source == null) {
      return;
    }
    await _operate(
      () => _service.importVideo(source),
      imported: true,
      cancellable: true,
    );
  }

  Widget _videoRow(Map<String, dynamic> video) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final sizeFormat = NumberFormat.decimalPattern(l.localeName)
      ..maximumFractionDigits = 1;
    final date = DateFormat.yMd(l.localeName).add_Hm().format(
      DateTime.fromMillisecondsSinceEpoch((video['importedAt'] as num).toInt()),
    );
    void play() => _operate(
      () => _service.play(video['id'] as String, l.videoDone),
      playing: true,
      cancellable: true,
    );
    return Semantics(
      customSemanticsActions: _canOperate
          ? {CustomSemanticsAction(label: l.deleteVideo): () => _delete(video)}
          : null,
      child: Slidable(
        key: ValueKey(video['id']),
        enabled: _canOperate,
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: .25,
          children: [
            SlidableAction(
              onPressed: (_) => _delete(video),
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              icon: Icons.delete_outline,
              label: l.delete,
            ),
          ],
        ),
        child: Material(
          color: colors.surface,
          child: InkWell(
            onTap: _canOperate ? play : null,
            onLongPress: _canOperate ? () => _delete(video) : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      color: colors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video['name'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          children: [
                            Text(
                              '${sizeFormat.format((video['size'] as num) / (1024 * 1024))} MB',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l.videoPlay,
                    onPressed: _canOperate ? play : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    color: colors.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _unlockedBody() {
    final l = context.l10n;
    return Column(
      children: [
        if (_busy)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_phaseText, style: const TextStyle(fontSize: 13)),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_progress != null)
                      Text(
                        NumberFormat.percentPattern(
                          l.localeName,
                        ).format(_progress),
                        style: const TextStyle(fontSize: 12),
                      ),
                    if (_cancellable)
                      TextButton(onPressed: _cancel, child: Text(l.cancel)),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: SlidableAutoCloseBehavior(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: _videos.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Text(
                      l.videoCount(_videos.length),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                if (index <= _videos.length) {
                  return Column(
                    children: [
                      _videoRow(_videos[index - 1]),
                      ColoredBox(
                        color: Theme.of(context).colorScheme.surface,
                        child: Divider(
                          height: 1,
                          indent: 68,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: .08),
                        ),
                      ),
                    ],
                  );
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    children: [
                      if (_videos.isEmpty && !_busy) ...[
                        const SizedBox(height: 36),
                        Icon(
                          Icons.lock_outline,
                          size: 36,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(l.videoEmpty, textAlign: TextAlign.center),
                        const SizedBox(height: 28),
                      ],
                      Text(
                        l.videoStorageNotice,
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(height: 1.6),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
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
      appBar: AppBar(
        title: Text(l.fileEncryption),
        actions: [
          if (_unlocked)
            IconButton(
              key: const ValueKey('video-import'),
              tooltip: l.videoImport,
              onPressed: _canOperate ? _showImportOptions : null,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
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
            Expanded(
              child: _unlocked
                  ? _unlockedBody()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
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
                          onPressed: _busy || !_hasSession
                              ? null
                              : () => _authenticate(),
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
                        if (_busy)
                          const Center(child: CircularProgressIndicator()),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
