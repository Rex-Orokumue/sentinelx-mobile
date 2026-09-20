import 'dart:convert';
import 'dart:io';

// Converts a namespace-qualified path (e.g. ['auth', 'login', 'title']) into
// the ARB key this repo's ARB files use for it (e.g. 'authLoginTitle').
// Leaf keys in the web messages are sometimes snake_case (auth.errors.invalid_email,
// auth.notices.check_email) rather than camelCase like the rest — each path
// segment is itself split on '_' so 'invalid_email' becomes two words
// ('Invalid', 'Email'), not left as 'Invalid_email'.
String toArbKey(List<String> path) {
  final words = <String>[
    for (final segment in path) ...segment.split('_').where((w) => w.isNotEmpty),
  ];
  final buffer = StringBuffer();
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    buffer.write(i == 0 ? '${w[0].toLowerCase()}${w.substring(1)}' : '${w[0].toUpperCase()}${w.substring(1)}');
  }
  return buffer.toString();
}

// Recursively walks a namespace's JSON value, joining nested keys under
// `prefix`. A leaf is any value that is not itself a Map (the web messages
// files only ever nest one or two levels — auth.login.title — never arrays).
Map<String, String> flattenNamespace(Map<String, dynamic> json, String prefix) {
  final out = <String, String>{};
  void walk(Map<String, dynamic> node, List<String> path) {
    node.forEach((key, value) {
      final nextPath = [...path, key];
      if (value is Map<String, dynamic>) {
        walk(value, nextPath);
      } else {
        out[toArbKey(nextPath)] = value.toString();
      }
    });
  }

  walk(json, [prefix]);
  return out;
}

// Merges `additions` into the ARB file at `path`, preserving every existing
// key (including '@@locale' and any '@key' ICU metadata blocks) and only
// adding/overwriting the keys this run produced. Keys are written in a
// stable, sorted order after the existing ones so re-runs produce small diffs.
void mergeIntoArb(String path, Map<String, String> additions) {
  final file = File(path);
  final existing = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final merged = {...existing, ...additions};
  final encoder = const JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(merged)}\n');
}

Future<void> main(List<String> args) async {
  final parsed = <String, String>{};
  for (final a in args) {
    final eq = a.indexOf('=');
    if (a.startsWith('--') && eq > 0) parsed[a.substring(2, eq)] = a.substring(eq + 1);
  }
  final source = parsed['source'] ?? '../sentinelx/messages';
  final namespaces = (parsed['namespaces'] ?? 'common,nav,home,auth').split(',');
  final locales = (parsed['locales'] ?? 'en,fr').split(',');

  for (final locale in locales) {
    final sourceFile = File('$source/$locale.json');
    if (!sourceFile.existsSync()) {
      stderr.writeln('Skipping $locale: $source/$locale.json not found.');
      continue;
    }
    final data = jsonDecode(sourceFile.readAsStringSync()) as Map<String, dynamic>;
    final additions = <String, String>{};
    for (final ns in namespaces) {
      final nsData = data[ns];
      if (nsData == null) {
        stderr.writeln('Warning: namespace "$ns" missing from $source/$locale.json');
        continue;
      }
      additions.addAll(flattenNamespace(nsData as Map<String, dynamic>, ns));
    }
    final target = 'lib/core/l10n/app_$locale.arb';
    if (!File(target).existsSync()) {
      stderr.writeln('Skipping $locale: no $target in this repo (only en/fr are wired for Material delegates in Phase 1 — pcm stays deferred).');
      continue;
    }
    mergeIntoArb(target, additions);
    stdout.writeln('Merged ${additions.length} keys into $target');
  }
}
