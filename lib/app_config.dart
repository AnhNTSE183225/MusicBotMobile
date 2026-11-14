abstract final class AppConfig {
  static const String env = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://theanh.tail38dac5.ts.net/api',
  );
  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://theanh.tail38dac5.ts.net/ws',
  );
  static const String loginUrl = String.fromEnvironment(
    'LOGIN_URL',
    defaultValue: 'https://theanh.tail38dac5.ts.net/login',
  );
  static const String frontendUrl = String.fromEnvironment(
    'FRONTEND_URL',
    defaultValue: 'https://musicbotui.pages.dev',
  );
  static const String sqliteDbName = String.fromEnvironment(
    'SQLITE_DB_NAME',
    defaultValue: 'musicbot_local.db',
  );

  static const bool isProd = env == 'prod';

  static const String uiRepoUrl = 'https://github.com/AnhNTSE183225/MusicBotUI';
  static const String uiIssuesUrl =
      'https://github.com/AnhNTSE183225/MusicBotUI/issues';
  static const String backendRepoUrl =
      'https://github.com/AnhNTSE183225/music-bot';
  static const String backendIssuesUrl =
      'https://github.com/AnhNTSE183225/music-bot/issues';
  static const String geminiKeyStudioUrl =
      'https://aistudio.google.com/app/apikey';
}
