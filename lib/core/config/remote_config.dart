import '../utils/version.dart';

class RemoteConfig {
  const RemoteConfig({
    required this.minSupportedAppVersion,
    required this.latestAppVersion,
    required this.maintenanceMessage,
    required this.siteUrl,
    required this.coinsPerNaira,
    required this.nairaPerCoin,
    required this.coinsPerEntry,
    required this.coinsHalfEntry,
    required this.enforcePhoneVerification,
    required this.whatsappCommunityUrl,
    required this.features,
  });

  factory RemoteConfig.fromJson(Map<String, dynamic> j) {
    final coins = j['coins'] as Map<String, dynamic>;
    final maintenance = j['maintenance'] as Map<String, dynamic>?;
    final features = (j['features'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as bool));
    return RemoteConfig(
      minSupportedAppVersion: j['minSupportedAppVersion'] as String,
      latestAppVersion: j['latestAppVersion'] as String,
      maintenanceMessage: maintenance?['message'] as String?,
      siteUrl: j['siteUrl'] as String,
      coinsPerNaira: (coins['coinsPerNaira'] as num).toInt(),
      nairaPerCoin: (coins['nairaPerCoin'] as num).toDouble(),
      coinsPerEntry: (coins['coinsPerEntry'] as num).toInt(),
      coinsHalfEntry: (coins['coinsHalfEntry'] as num).toInt(),
      enforcePhoneVerification: j['enforcePhoneVerification'] as bool,
      whatsappCommunityUrl: j['whatsappCommunityUrl'] as String?,
      features: features,
    );
  }

  final String minSupportedAppVersion;
  final String latestAppVersion;
  final String? maintenanceMessage;
  final String siteUrl;
  final int coinsPerNaira;
  final double nairaPerCoin;
  final int coinsPerEntry;
  final int coinsHalfEntry;
  final bool enforcePhoneVerification;
  final String? whatsappCommunityUrl;
  final Map<String, bool> features;

  /// A flag the server does not know about is not gated.
  bool feature(String key) => features[key] ?? true;
}

enum GateKind { open, maintenance, updateRequired }

class GateState {
  const GateState(this.kind, {this.message, this.minVersion});
  final GateKind kind;
  final String? message;
  final String? minVersion;
}

GateState evaluateGate(RemoteConfig? config, String installedVersion) {
  if (config == null) return const GateState(GateKind.open);
  if (config.maintenanceMessage != null) {
    return GateState(GateKind.maintenance, message: config.maintenanceMessage);
  }
  if (compareVersions(installedVersion, config.minSupportedAppVersion) < 0) {
    return GateState(GateKind.updateRequired, minVersion: config.minSupportedAppVersion);
  }
  return const GateState(GateKind.open);
}
