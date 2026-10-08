enum AppEnvironment { dev, hml, prod }

class AppEnv {
  static const _raw = String.fromEnvironment('APP_ENV', defaultValue: 'prod');

  static AppEnvironment get current {
    switch (_raw.toLowerCase()) {
      case 'dev':
        return AppEnvironment.dev;
      case 'hml':
      case 'homolog':
        return AppEnvironment.hml;
      default:
        return AppEnvironment.prod;
    }
  }

  static bool get isProd => current == AppEnvironment.prod;
  static bool get isDevLike => current == AppEnvironment.dev || current == AppEnvironment.hml;
  static String get name => current.name;
}
