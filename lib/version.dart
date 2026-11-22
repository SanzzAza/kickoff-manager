// Naikkan angka ini tiap rilis (atau lewat CI: --dart-define=APP_VERSION=x.y.z).
const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
const String appBuild = String.fromEnvironment('APP_BUILD', defaultValue: '1');
