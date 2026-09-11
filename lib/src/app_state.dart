import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'runtime.dart';
import 'server.dart';
import 'storage.dart';

final settingsServiceProvider = Provider((ref) => SettingsService());
final modelStoreProvider = Provider((ref) => ModelStore());
final modelImporterProvider = Provider((ref) => ModelImporter());
final runtimeManagerProvider = Provider((ref) => RuntimeManager());
final inferenceSchedulerProvider = Provider((ref) {
  final scheduler = InferenceScheduler();
  ref.onDispose(scheduler.dispose);
  return scheduler;
});
final resourceManagerProvider = Provider((ref) => RuntimeResourceManager());

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.read(settingsServiceProvider));
});

final modelsProvider = StateNotifierProvider<ModelsNotifier, List<ModelDescriptor>>((ref) {
  return ModelsNotifier(
    store: ref.read(modelStoreProvider),
    importer: ref.read(modelImporterProvider),
    runtimeManager: ref.read(runtimeManagerProvider),
  );
});

final localApiServerProvider = Provider<LocalApiServer>((ref) {
  final server = LocalApiServer(
    models: () => ref.read(modelsProvider),
    runtimeHealth: ref.read(runtimeManagerProvider).health,
  );
  ref.onDispose(server.dispose);
  return server;
});

final serverStateProvider = StateNotifierProvider<ServerNotifier, ServerState>((ref) {
  final notifier = ServerNotifier(
    server: ref.read(localApiServerProvider),
    readSettings: () => ref.read(settingsProvider),
  );
  ref.onDispose(notifier.dispose);
  return notifier;
});

final runtimeHealthProvider = FutureProvider<List<RuntimeHealth>>((ref) {
  return ref.read(runtimeManagerProvider).health();
});

final appBootstrapProvider = FutureProvider<void>((ref) async {
  await Future.wait([
    ref.read(settingsProvider.notifier).load(),
    ref.read(modelsProvider.notifier).load(),
  ]);
  final settings = ref.read(settingsProvider);
  if (settings.autoStartServer) {
    await ref.read(serverStateProvider.notifier).start();
  }
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._service) : super(const AppSettings());

  final SettingsService _service;

  Future<void> load() async {
    state = await _service.load();
  }

  Future<void> update(AppSettings next) async {
    state = next;
    await _service.save(next);
  }

  Future<void> setTheme(String themeMode) =>
      update(state.copyWith(themeMode: themeMode));

  Future<void> setServerPort(int port) => update(state.copyWith(serverPort: port));

  Future<void> setRequireApiKey(bool value) =>
      update(state.copyWith(requireApiKey: value));

  Future<void> setLanAccess(bool value) => update(state.copyWith(lanAccess: value));

  Future<void> setCors(bool value) => update(state.copyWith(cors: value));

  Future<void> setAutoStart(bool value) =>
      update(state.copyWith(autoStartServer: value));

  Future<String> generateApiKey() async {
    final key = 'eb_${const Uuid().v4().replaceAll('-', '')}';
    await update(state.copyWith(apiKey: key, requireApiKey: true));
    return key;
  }
}

class ModelsNotifier extends StateNotifier<List<ModelDescriptor>> {
  ModelsNotifier({
    required ModelStore store,
    required ModelImporter importer,
    required RuntimeManager runtimeManager,
  })  : _store = store,
        _importer = importer,
        _runtimeManager = runtimeManager,
        super(const []);

  final ModelStore _store;
  final ModelImporter _importer;
  final RuntimeManager _runtimeManager;

  Future<void> load() async {
    state = await _store.load();
  }

  Future<ModelDescriptor?> import({ModelType? type}) async {
    final descriptor = await _importer.pickAndImport(expectedType: type);
    if (descriptor == null) return null;
    state = [...state, descriptor];
    await _persist();
    return descriptor;
  }

  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = [
      for (final model in state)
        if (model.id == id) model.copyWith(name: trimmed) else model,
    ];
    await _persist();
  }

  Future<void> setDefault(String id) async {
    final target = state.where((m) => m.id == id).firstOrNull;
    if (target == null) return;
    state = [
      for (final model in state)
        if (model.type == target.type)
          model.copyWith(isDefault: model.id == id)
        else
          model,
    ];
    await _persist();
  }

  Future<void> toggleLoaded(String id) async {
    final index = state.indexWhere((model) => model.id == id);
    if (index < 0) return;
    final model = state[index];
    if (!_runtimeManager.bridge.available) {
      throw StateError(
        'Native runtime bridge is not linked. Build native/libeburon_runtime for this platform first.',
      );
    }

    // The app-level lifecycle is implemented here. Concrete native model load/unload
    // is delegated to the runtime adapter behind libeburon_runtime.
    final updated = model.copyWith(loaded: !model.loaded);
    final next = [...state];
    next[index] = updated;
    state = next;
    await _persist();
  }

  Future<void> delete(String id) async {
    final model = state.where((m) => m.id == id).firstOrNull;
    if (model == null) return;
    final entity = FileSystemEntity.typeSync(model.path);
    if (entity == FileSystemEntityType.directory) {
      final dir = Directory(model.path);
      if (await dir.exists()) await dir.delete(recursive: true);
    } else if (entity == FileSystemEntityType.file) {
      final file = File(model.path);
      if (await file.exists()) {
        final parent = file.parent;
        await file.delete();
        if (await parent.exists()) await parent.delete(recursive: true);
      }
    }
    state = state.where((m) => m.id != id).toList(growable: false);
    await _persist();
  }

  Future<void> _persist() => _store.save(state);
}

class ServerState {
  const ServerState({
    this.running = false,
    this.lanUrl,
    this.activeRequests = 0,
    this.lastRequest,
    this.error,
  });

  final bool running;
  final String? lanUrl;
  final int activeRequests;
  final String? lastRequest;
  final String? error;

  ServerState copyWith({
    bool? running,
    String? lanUrl,
    int? activeRequests,
    String? lastRequest,
    String? error,
    bool clearError = false,
  }) {
    return ServerState(
      running: running ?? this.running,
      lanUrl: lanUrl ?? this.lanUrl,
      activeRequests: activeRequests ?? this.activeRequests,
      lastRequest: lastRequest ?? this.lastRequest,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class ServerNotifier extends StateNotifier<ServerState> {
  ServerNotifier({
    required LocalApiServer server,
    required AppSettings Function() readSettings,
  })  : _server = server,
        _readSettings = readSettings,
        super(const ServerState()) {
    _activitySub = _server.activity.listen(_onActivity);
  }

  final LocalApiServer _server;
  final AppSettings Function() _readSettings;
  StreamSubscription<ServerActivity>? _activitySub;
  final Set<String> _active = {};

  Future<void> start() async {
    try {
      await _server.start(_readSettings());
      state = state.copyWith(
        running: true,
        lanUrl: await _server.lanUrl() ?? 'http://127.0.0.1:${_server.port}',
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(running: false, error: error.toString());
      rethrow;
    }
  }

  Future<void> stop() async {
    await _server.stop();
    _active.clear();
    state = state.copyWith(running: false, activeRequests: 0, clearError: true);
  }

  Future<void> restart() async {
    try {
      await _server.restart(_readSettings());
      state = state.copyWith(
        running: true,
        lanUrl: await _server.lanUrl() ?? 'http://127.0.0.1:${_server.port}',
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(error: error.toString());
      rethrow;
    }
  }

  void _onActivity(ServerActivity activity) {
    if (activity.active) {
      _active.add(activity.requestId);
    } else {
      _active.remove(activity.requestId);
    }
    state = state.copyWith(
      activeRequests: _active.length,
      lastRequest: '${activity.method} ${activity.path}',
    );
  }

  Future<void> dispose() async {
    await _activitySub?.cancel();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
