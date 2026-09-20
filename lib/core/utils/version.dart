List<int> _parts(String v) => v.split('+').first.split('.').map((s) => int.tryParse(s) ?? 0).toList();

/// Numeric dotted-version comparison, ignoring a `+build` suffix. Mirrors lib/mobile-api/version.ts
/// in the web repo; keep the test vectors identical.
int compareVersions(String a, String b) {
  final pa = _parts(a);
  final pb = _parts(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x < y) return -1;
    if (x > y) return 1;
  }
  return 0;
}
