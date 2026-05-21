import 'dart:collection';
import 'dart:convert';
import 'dart:io';

const String _defaultBaseUrl =
    'https://recircle2000.github.io/hotong_station_image';
const String _defaultOutputDirectory = 'build/bus_static';

void main(List<String> args) async {
  final options = _BuildOptions.parse(args);
  if (exitCode != 0) {
    return;
  }
  if (options.version == null) {
    _printUsageAndExit();
    return;
  }

  final version = options.version!;
  if (!RegExp(r'^\d{4}\.\d{2}\.\d{2}$').hasMatch(version)) {
    stderr.writeln('version must use yyyy.MM.dd format.');
    exitCode = 64;
    return;
  }

  final routes = await _readJsonDirectory(Directory('assets/bus_routes'));
  final stops = await _readJsonDirectory(Directory('assets/bus_stops'));
  if (exitCode != 0) {
    return;
  }

  final outputDirectory = Directory(options.outputDirectory);
  await outputDirectory.create(recursive: true);

  final dataFile =
      File(_joinPath(outputDirectory.path, 'bus_static_data.json'));
  final manifestFile =
      File(_joinPath(outputDirectory.path, 'bus_static_manifest.json'));
  final downloadUrl =
      '${options.baseUrl.replaceFirst(RegExp(r'/$'), '')}/bus_static_data.json';
  final manifest = <String, dynamic>{
    'version': version,
    'downloadUrl': downloadUrl,
  };
  if (options.effectiveFrom != null) {
    manifest['effectiveFrom'] = options.effectiveFrom;
  }

  const encoder = JsonEncoder.withIndent('  ');
  await dataFile.writeAsString(
    '${encoder.convert({
          'version': version,
          'routes': routes,
          'stops': stops,
        })}\n',
    encoding: utf8,
  );
  await manifestFile.writeAsString(
    '${encoder.convert(manifest)}\n',
    encoding: utf8,
  );

  stdout.writeln('Generated ${dataFile.path}');
  stdout.writeln('Generated ${manifestFile.path}');
}

Future<SplayTreeMap<String, dynamic>> _readJsonDirectory(
  Directory directory,
) async {
  if (!await directory.exists()) {
    stderr.writeln('Directory not found: ${directory.path}');
    exitCode = 66;
    return SplayTreeMap<String, dynamic>();
  }

  final files = directory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.toLowerCase().endsWith('.json'))
      .toList()
    ..sort((left, right) => left.path.compareTo(right.path));

  final data = SplayTreeMap<String, dynamic>();
  for (final file in files) {
    final fileName = _basename(file.path);
    final routeKey = fileName.substring(0, fileName.length - '.json'.length);
    final decoded = json.decode(await file.readAsString(encoding: utf8));
    if (decoded is! Map) {
      stderr.writeln('JSON root must be an object: ${file.path}');
      exitCode = 65;
      continue;
    }
    data[routeKey] = decoded;
  }

  return data;
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.lastIndexOf('/') + 1);
}

String _joinPath(String directoryPath, String fileName) {
  if (directoryPath.endsWith(Platform.pathSeparator)) {
    return '$directoryPath$fileName';
  }

  return '$directoryPath${Platform.pathSeparator}$fileName';
}

void _printUsageAndExit() {
  stderr.writeln(
    'Usage: dart run tool/build_bus_static_data.dart '
    '--version yyyy.MM.dd [--effective-from ISO-8601] '
    '[--output build/bus_static] [--base-url URL]',
  );
  exitCode = 64;
}

class _BuildOptions {
  const _BuildOptions({
    required this.version,
    required this.effectiveFrom,
    required this.outputDirectory,
    required this.baseUrl,
  });

  final String? version;
  final String? effectiveFrom;
  final String outputDirectory;
  final String baseUrl;

  static _BuildOptions parse(List<String> args) {
    String? version;
    String? effectiveFrom;
    var outputDirectory = _defaultOutputDirectory;
    var baseUrl = _defaultBaseUrl;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--version' && i + 1 < args.length) {
        version = args[++i];
      } else if (arg.startsWith('--version=')) {
        version = arg.substring('--version='.length);
      } else if (arg == '--effective-from' && i + 1 < args.length) {
        effectiveFrom = args[++i];
      } else if (arg.startsWith('--effective-from=')) {
        effectiveFrom = arg.substring('--effective-from='.length);
      } else if (arg == '--output' && i + 1 < args.length) {
        outputDirectory = args[++i];
      } else if (arg.startsWith('--output=')) {
        outputDirectory = arg.substring('--output='.length);
      } else if (arg == '--base-url' && i + 1 < args.length) {
        baseUrl = args[++i];
      } else if (arg.startsWith('--base-url=')) {
        baseUrl = arg.substring('--base-url='.length);
      } else {
        stderr.writeln('Unknown or incomplete argument: $arg');
        _printUsageAndExit();
        return _BuildOptions(
          version: version,
          effectiveFrom: effectiveFrom,
          outputDirectory: outputDirectory,
          baseUrl: baseUrl,
        );
      }
    }

    if (effectiveFrom != null && DateTime.tryParse(effectiveFrom) == null) {
      stderr.writeln('effective-from must be a valid ISO-8601 date time.');
      _printUsageAndExit();
    }

    return _BuildOptions(
      version: version,
      effectiveFrom: effectiveFrom,
      outputDirectory: outputDirectory,
      baseUrl: baseUrl,
    );
  }
}
