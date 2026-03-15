/// A Thymeleaf-inspired HTML template engine for Dart.
///
/// Natural HTML templates with `tl:*` attributes.
/// Fragment-first design for HTMX partial rendering.
library;

export 'src/cache_stats.dart' show CacheStats;
export 'src/context_builder.dart' show TrellisContext;
export 'src/engine.dart' show Trellis;
export 'src/evaluator.dart' show ExpressionEvaluator;
export 'src/exceptions.dart'
    show
        TemplateException,
        ExpressionException,
        FragmentNotFoundException,
        TemplateNotFoundException,
        TemplateSecurityException;
export 'src/loaders/template_loader.dart' show TemplateLoader;
export 'src/loaders/file_loader.dart' show FileSystemLoader;
export 'src/loaders/map_loader.dart' show MapLoader;
export 'src/loaders/asset_loader.dart' show AssetLoader;
export 'src/loaders/composite_loader.dart' show CompositeLoader;
export 'src/processor_api.dart' show Processor, ProcessorPriority, ProcessorContext;
export 'src/dialect.dart' show Dialect, StandardDialect;
export 'src/message_source.dart' show MessageSource, MapMessageSource;
export 'src/validator.dart' show TemplateValidator, ValidationError, ValidationSeverity;
export 'src/warm_up_result.dart' show WarmUpResult;
