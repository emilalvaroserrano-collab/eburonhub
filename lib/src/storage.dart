import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = 'dark',
    this.serverPort = 8080,
    this.requireApiKey = false,
    this.apiKey = '',
    this.autoStartServer = false,
    this.lanAccess = true,
    this.cors = true,
    this.llmContextSize = 4096,
    this.llmThreads = 4,
    this.llmGpuLayers = 0,
    this.llmMaxTokens = 1024,
    this.llmTemperature = 0.7,
    this.systemPrompt = 'You are a helpful local AI assistant.',
    this.sttLanguage = 'auto',
    this.sttVad = true,
    this.sttSilenceTimeoutMs = 900,
    this.sttConfidenceThreshold = 0.5,
    this.ttsVoice = 'default',
    this.ttsSpeed = 1.0,
    this.ttsAudioFormat = 'wav',
    this.ttsStreamingBufferMs = 200,
    this.ttsSentenceChunking = true,
    this.imageSize = '1024x1024',
    this.imageSteps = 20,
    this.imageCfg = 7.0,
    this.imageSampler = 'euler_a',
    this.imageScheduler = 'discrete',
  });

  final String themeMode;
  final int serverPort;
  final bool requireApiKey;
  final String apiKey;
  final bool autoStartServer;
  final bool lanAccess;
  final bool cors;
  final int llmContextSize;
  final int llmThreads;
  final int llmGpuLayers;
  final int llmMaxTokens;
  final double llmTemperature;
  final String systemPrompt;
  final String sttLanguage;
  final bool sttVad;
  final int sttSilenceTimeoutMs;
  final double sttConfidenceThreshold;
  final String ttsVoice;
  final double ttsSpeed;
  final String ttsAudioFormat;
  final int ttsStreamingBufferMs;
  final bool ttsSentenceChunking;
  final String imageSize;
  final int imageSteps;
  final double imageCfg;
  final String imageSampler;
  final String imageScheduler;

  AppSettings copyWith({
    String? themeMode,
    int? serverPort,
    bool? requireApiKey,
    String? apiKey,
    bool? autoStartServer,
    bool? lanAccess,
    bool? cors,
    int? llmContextSize,
    int? llmThreads,
    int? llmGpuLayers,
    int? llmMaxTokens,
    double? llmTemperature,
    String? systemPrompt,
    String? sttLanguage,
    bool? sttVad,
    int? sttSilenceTimeoutMs,
    double? sttConfidenceThreshold,
    String? ttsVoice,
    double? ttsSpeed,
    String? ttsAudioFormat,
    int? ttsStreamingBufferMs,
    bool? ttsSentenceChunking,
    String? imageSize,
    int? imageSteps,
    double? imageCfg,
    String? imageSampler,
    String? imageScheduler,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      serverPort: serverPort ?? this.serverPort,
      requireApiKey: requireApiKey ?? this.requireApiKey,
      apiKey: apiKey ?? this.apiKey,
      autoStartServer: autoStartServer ?? this.autoStartServer,
      lanAccess: lanAccess ?? this.lanAccess,
      cors: cors ?? this.cors,
      llmContextSize: llmContextSize ?? this.llmContextSize,
      llmThreads: llmThreads ?? this.llmThreads,
      llmGpuLayers: llmGpuLayers ?? this.llmGpuLayers,
      llmMaxTokens: llmMaxTokens ?? this.llmMaxTokens,
      llmTemperature: llmTemperature ?? this.llmTemperature,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      sttLanguage: sttLanguage ?? this.sttLanguage,
      sttVad: sttVad ?? this.sttVad,
      sttSilenceTimeoutMs: sttSilenceTimeoutMs ?? this.sttSilenceTimeoutMs,
      sttConfidenceThreshold:
          sttConfidenceThreshold ?? this.sttConfidenceThreshold,
      ttsVoice: ttsVoice ?? this.ttsVoice,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      ttsAudioFormat: ttsAudioFormat ?? this.ttsAudioFormat,
      ttsStreamingBufferMs:
          ttsStreamingBufferMs ?? this.ttsStreamingBufferMs,
      ttsSentenceChunking:
          ttsSentenceChunking ?? this.ttsSentenceChunking,
      imageSize: imageSize ?? this.imageSize,
      imageSteps: imageSteps ?? this.imageSteps,
      imageCfg: imageCfg ?? this.imageCfg,
      imageSampler: imageSampler ?? this.imageSampler,
      imageScheduler: imageScheduler ?? this.imageScheduler,
    );
  }

  Map<String, Object?> toJson() => {
        'themeMode': themeMode,
        'serverPort': serverPort,
        'requireApiKey': requireApiKey,
        'apiKey': apiKey,
        'autoStartServer': autoStartServer,
        'lanAccess': lanAccess,
        'cors': cors,
        'llmContextSize': llmContextSize,
        'llmThreads': llmThreads,
        'llmGpuLayers': llmGpuLayers,
        'llmMaxTokens': llmMaxTokens,
        'llmTemperature': llmTemperature,
        'systemPrompt': systemPrompt,
        'sttLanguage': sttLanguage,
        'sttVad': sttVad,
        'sttSilenceTimeoutMs': sttSilenceTimeoutMs,
        'sttConfidenceThreshold': sttConfidenceThreshold,
        'ttsVoice': ttsVoice,
        'ttsSpeed': ttsSpeed,
        'ttsAudioFormat': ttsAudioFormat,
        'ttsStreamingBufferMs': ttsStreamingBufferMs,
        'ttsSentenceChunking': ttsSentenceChunking,
        'imageSize': imageSize,
        'imageSteps': imageSteps,
        'imageCfg': imageCfg,
        'imageSampler': imageSampler,
        'imageScheduler': imageScheduler,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final defaults = const AppSettings();
    return AppSettings(
      themeMode: json['themeMode'] as String? ?? defaults.themeMode,
      serverPort: (json['serverPort'] as num?)?.toInt() ?? defaults.serverPort,
      requireApiKey: json['requireApiKey'] as bool? ?? defaults.requireApiKey,
      apiKey: json['apiKey'] as String? ?? defaults.apiKey,
      autoStartServer:
          json['autoStartServer'] as bool? ?? defaults.autoStartServer,
      lanAccess: json['lanAccess'] as bool? ?? defaults.lanAccess,
      cors: json['cors'] as bool? ?? defaults.cors,
      llmContextSize:
          (json['llmContextSize'] as num?)?.toInt() ?? defaults.llmContextSize,
      llmThreads:
          (json['llmThreads'] as num?)?.toInt() ?? defaults.llmThreads,
      llmGpuLayers:
          (json['llmGpuLayers'] as num?)?.toInt() ?? defaults.llmGpuLayers,
      llmMaxTokens:
          (json['llmMaxTokens'] as num?)?.toInt() ?? defaults.llmMaxTokens,
      llmTemperature: (json['llmTemperature'] as num?)?.toDouble() ??
          defaults.llmTemperature,
      systemPrompt: json['systemPrompt'] as String? ?? defaults.systemPrompt,
      sttLanguage: json['sttLanguage'] as String? ?? defaults.sttLanguage,
      sttVad: json['sttVad'] as bool? ?? defaults.sttVad,
      sttSilenceTimeoutMs: (json['sttSilenceTimeoutMs'] as num?)?.toInt() ??
          defaults.sttSilenceTimeoutMs,
      sttConfidenceThreshold:
          (json['sttConfidenceThreshold'] as num?)?.toDouble() ??
              defaults.sttConfidenceThreshold,
      ttsVoice: json['ttsVoice'] as String? ?? defaults.ttsVoice,
      ttsSpeed: (json['ttsSpeed'] as num?)?.toDouble() ?? defaults.ttsSpeed,
      ttsAudioFormat:
          json['ttsAudioFormat'] as String? ?? defaults.ttsAudioFormat,
      ttsStreamingBufferMs:
          (json['ttsStreamingBufferMs'] as num?)?.toInt() ??
              defaults.ttsStreamingBufferMs,
      ttsSentenceChunking:
          json['ttsSentenceChunking'] as bool? ?? defaults.ttsSentenceChunking,
      imageSize: json['imageSize'] as String? ?? defaults.imageSize,
      imageSteps:
          (json['imageSteps'] as num?)?.toInt() ?? defaults.imageSteps,
      imageCfg: (json['imageCfg'] as num?)?.toDouble() ?? defaults.imageCfg,
      imageSampler: json['imageSampler'] as String? ?? defaults.imageSampler,
      imageScheduler:
          json['imageScheduler'] as String? ?? defaults.imageScheduler,
    );
  }
}

class SettingsService {
  static const _key = 'eburon_hub_settings_v1';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}

class ModelStore {
  static const _key = 'eburon_hub_models_v1';

  Future<List<ModelDescriptor>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => ModelDescriptor.fromJson(
                Map<String, Object?>.from(e as Map<dynamic, dynamic>),
              ))
          .map((model) => model.copyWith(loaded: false))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<ModelDescriptor> models) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(models.map((e) => e.toJson()).toList()),
    );
  }
}

class ModelImporter {
  ModelImporter({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  Future<ModelDescriptor?> pickAndImport({ModelType? expectedType}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
      type: FileType.custom,
      allowedExtensions: [
        'gguf',
        'bin',
        'safetensors',
        'ckpt',
        'zip',
        'eburonmodel',
      ],
    );
    if (result == null || result.files.single.path == null) return null;
    return importPath(result.files.single.path!, expectedType: expectedType);
  }

  Future<ModelDescriptor> importPath(
    String sourcePath, {
    ModelType? expectedType,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Model file not found', sourcePath);
    }

    final lower = sourcePath.toLowerCase();
    if (lower.endsWith('.eburonmodel') || lower.endsWith('.zip')) {
      return _importPackage(source, expectedType: expectedType);
    }
    return _importSingleFile(source, expectedType: expectedType);
  }

  Future<ModelDescriptor> _importSingleFile(
    File source, {
    ModelType? expectedType,
  }) async {
    final ext = p.extension(source.path).toLowerCase();
    final fileName = p.basename(source.path);
    late final ModelType type;
    late final RuntimeKind runtime;
    late final ModelFormat format;
    late final String architecture;

    switch (ext) {
      case '.gguf':
        type = expectedType ?? ModelType.llm;
        if (type == ModelType.image) {
          runtime = RuntimeKind.stableDiffusionCpp;
          architecture = 'diffusion';
        } else if (type == ModelType.llm) {
          runtime = RuntimeKind.llamaCpp;
          architecture = _guessLlmArchitecture(fileName);
        } else {
          throw FormatException(
            'Raw GGUF is supported for LLM or image models; use an .eburonmodel package for $type.',
          );
        }
        format = ModelFormat.gguf;
      case '.safetensors':
        type = ModelType.image;
        runtime = RuntimeKind.stableDiffusionCpp;
        format = ModelFormat.safetensors;
        architecture = _guessImageArchitecture(fileName);
      case '.ckpt':
        type = ModelType.image;
        runtime = RuntimeKind.stableDiffusionCpp;
        format = ModelFormat.ckpt;
        architecture = _guessImageArchitecture(fileName);
      case '.bin':
        if (!fileName.toLowerCase().startsWith('ggml-')) {
          throw const FormatException(
            'Raw .bin imports are reserved for whisper.cpp ggml-*.bin models.',
          );
        }
        type = ModelType.stt;
        runtime = RuntimeKind.whisperCpp;
        format = ModelFormat.ggmlBin;
        architecture = 'whisper';
      default:
        throw FormatException('Unsupported model file: $fileName');
    }

    if (expectedType != null && expectedType != type) {
      throw FormatException(
        'Selected ${expectedType.wireName} slot cannot import detected ${type.wireName} model.',
      );
    }

    final root = await _modelRoot();
    final id = _uuid.v4();
    final destinationDir = Directory(p.join(root.path, id));
    await destinationDir.create(recursive: true);
    final destination = File(p.join(destinationDir.path, fileName));
    await source.copy(destination.path);
    final size = await destination.length();
    final checksum = await _sha256File(destination);

    return ModelDescriptor(
      id: id,
      name: p.basenameWithoutExtension(fileName),
      type: type,
      runtime: runtime,
      architecture: architecture,
      format: format,
      sizeBytes: size,
      path: destination.path,
      quantization: _guessQuantization(fileName),
      capabilities: _defaultCapabilities(type),
      checksum: checksum,
    );
  }

  Future<ModelDescriptor> _importPackage(
    File source, {
    ModelType? expectedType,
  }) async {
    final bytes = await source.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final manifestEntry = archive.findFile('manifest.json');
    if (manifestEntry == null || !manifestEntry.isFile) {
      throw const FormatException('Package is missing manifest.json');
    }

    final manifest = jsonDecode(utf8.decode(manifestEntry.content))
        as Map<String, dynamic>;
    final schema = (manifest['schema'] as num?)?.toInt();
    if (schema != 1) {
      throw FormatException('Unsupported .eburonmodel schema: $schema');
    }

    final type = ModelTypeWire.fromWire(manifest['type'] as String? ?? '');
    final runtime =
        RuntimeKindWire.fromWire(manifest['runtime'] as String? ?? '');
    if (runtime == RuntimeKind.unknown) {
      throw FormatException('Unsupported runtime: ${manifest['runtime']}');
    }
    if (expectedType != null && expectedType != type) {
      throw FormatException(
        'Selected ${expectedType.wireName} slot cannot import ${type.wireName} package.',
      );
    }

    final declaredFiles = _declaredFiles(manifest['files']);
    if (declaredFiles.isEmpty) {
      throw const FormatException('manifest.files must declare model dependencies');
    }
    for (final file in declaredFiles.values) {
      if (archive.findFile(file.path) == null) {
        throw FormatException('Missing package dependency: ${file.path}');
      }
    }

    final id = manifest['id'] as String? ?? _uuid.v4();
    final root = await _modelRoot();
    final destinationDir = Directory(p.join(root.path, _safeId(id)));
    if (await destinationDir.exists()) {
      await destinationDir.delete(recursive: true);
    }
    await destinationDir.create(recursive: true);

    int totalBytes = 0;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      if (entry.symbolicLink != null) {
        throw FormatException('Symlinks are not allowed: ${entry.name}');
      }
      final safeRelative = _safeArchivePath(entry.name);
      final output = File(p.join(destinationDir.path, safeRelative));
      await output.parent.create(recursive: true);
      await output.writeAsBytes(entry.content, flush: true);
      totalBytes += entry.size;
    }

    for (final file in declaredFiles.values) {
      if (file.sha256 == null || file.sha256!.isEmpty) continue;
      final actual = await _sha256File(File(p.join(destinationDir.path, file.path)));
      if (actual.toLowerCase() != file.sha256!.toLowerCase()) {
        await destinationDir.delete(recursive: true);
        throw FormatException('Checksum mismatch: ${file.path}');
      }
    }

    final languages = (manifest['languages'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(growable: false);
    final capabilities =
        (manifest['capabilities'] as List<dynamic>? ?? _defaultCapabilities(type))
            .map((e) => e.toString())
            .toList(growable: false);

    return ModelDescriptor(
      id: id,
      name: manifest['name'] as String? ?? id,
      type: type,
      runtime: runtime,
      architecture: manifest['architecture'] as String? ?? 'unknown',
      format: ModelFormat.eburonModel,
      sizeBytes: totalBytes,
      languages: languages,
      quantization: manifest['quantization'] as String?,
      capabilities: capabilities,
      path: destinationDir.path,
      version: manifest['version'] as String?,
      metadata: Map<String, Object?>.from(manifest),
    );
  }

  Map<String, _DeclaredFile> _declaredFiles(Object? rawFiles) {
    if (rawFiles is! Map) return const {};
    final result = <String, _DeclaredFile>{};
    for (final entry in rawFiles.entries) {
      final value = entry.value;
      if (value is String) {
        result[entry.key.toString()] = _DeclaredFile(_safeArchivePath(value));
      } else if (value is Map) {
        final pathValue = value['path']?.toString();
        if (pathValue == null) continue;
        result[entry.key.toString()] = _DeclaredFile(
          _safeArchivePath(pathValue),
          sha256: value['sha256']?.toString(),
        );
      }
    }
    return result;
  }

  String _safeArchivePath(String raw) {
    final normalized = p.posix.normalize(raw.replaceAll('\\', '/'));
    if (normalized.startsWith('/') ||
        normalized == '..' ||
        normalized.startsWith('../')) {
      throw FormatException('Unsafe package path: $raw');
    }
    return normalized;
  }

  String _safeId(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  Future<Directory> _modelRoot() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(p.join(support.path, 'models'));
    await root.create(recursive: true);
    return root;
  }

  Future<String> _sha256File(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  String _guessLlmArchitecture(String name) {
    final n = name.toLowerCase();
    if (n.contains('qwen')) return 'qwen';
    if (n.contains('gemma')) return 'gemma';
    if (n.contains('smollm')) return 'smollm';
    if (n.contains('phi')) return 'phi';
    if (n.contains('llama')) return 'llama';
    return 'gguf-llm';
  }

  String _guessImageArchitecture(String name) {
    final n = name.toLowerCase();
    if (n.contains('flux')) return 'flux';
    if (n.contains('sdxl')) return 'sdxl';
    if (n.contains('sd3')) return 'sd3';
    return 'stable-diffusion';
  }

  String? _guessQuantization(String name) {
    final match = RegExp(r'(Q\d(?:_[A-Z0-9]+)?|IQ\d_[A-Z0-9]+)', caseSensitive: false)
        .firstMatch(name);
    return match?.group(1)?.toUpperCase();
  }

  List<String> _defaultCapabilities(ModelType type) => switch (type) {
        ModelType.llm => const ['chat', 'completion', 'streaming'],
        ModelType.stt => const ['transcription'],
        ModelType.tts => const ['speech'],
        ModelType.image => const ['txt2img'],
      };
}

class _DeclaredFile {
  const _DeclaredFile(this.path, {this.sha256});
  final String path;
  final String? sha256;
}
