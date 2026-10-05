// Rewrites test/fixtures/web_sticker_pack.json from the web repo's sticker pack so a web-side change shows up
// as a failing drift test (test/features/messages/stickers_test.dart). CI cannot see the web repo, so this runs
// when the pack is synced, not on every build.
//
//   dart run tool/sync_stickers.dart C:\Users\gorok\Videos\sentinelx
//
// Output is written as UTF-8 explicitly (no BOM): Windows' default console encoding would corrupt the emoji.
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/sync_stickers.dart <path to web checkout>');
    exit(64);
  }
  final result = await Process.run(
    'git',
    ['-C', args.first, 'show', 'origin/main:lib/messages/stickers.ts'],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) {
    stderr.writeln('git show failed: ${result.stderr}');
    exit(1);
  }
  final entry = RegExp(r"\{\s*id:\s*'([^']+)',\s*emoji:\s*'([^']+)'");
  final pack = [
    for (final m in entry.allMatches(result.stdout as String)) {'id': m.group(1), 'emoji': m.group(2)},
  ];
  if (pack.isEmpty) {
    stderr.writeln('no stickers parsed; did the web file format change?');
    exit(1);
  }
  final out = File('test/fixtures/web_sticker_pack.json');
  out.createSync(recursive: true);
  out.writeAsBytesSync(utf8.encode('${const JsonEncoder.withIndent('  ').convert(pack)}\n'));
  stdout.writeln('wrote ${pack.length} stickers to ${out.path}');
}
