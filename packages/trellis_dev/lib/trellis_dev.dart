/// Developer tools for the Trellis template engine.
///
/// Provides SSE-based browser hot reload for rapid template development, driven
/// by a template loader's watcher (`devMiddleware`) or by any change stream
/// (`liveReloadMiddleware`).
library;

export 'src/dev_middleware.dart' show devMiddleware;
export 'src/live_reload_middleware.dart' show liveReloadMiddleware;
export 'src/live_reload_handler.dart' show liveReloadHandler, liveReloadScript, liveReloadClientScript;
