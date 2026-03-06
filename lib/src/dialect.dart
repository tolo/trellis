import 'processor_api.dart';
import 'processors/attr_processor.dart';
import 'processors/condition_processor.dart';
import 'processors/each_processor.dart';
import 'processors/fragment_processor.dart';
import 'processors/inline_processor.dart';
import 'processors/object_processor.dart';
import 'processors/remove_processor.dart';
import 'processors/switch_processor.dart';
import 'processors/text_processor.dart';
import 'processors/with_processor.dart';

/// Named bundle of processors + filters [D10].
abstract class Dialect {
  /// Human-readable dialect name (e.g. 'Standard', 'Markdown').
  String get name;

  /// Processors contributed by this dialect.
  List<Processor> get processors;

  /// Filters contributed by this dialect. Defaults to empty.
  Map<String, Function> get filters => const {};
}

/// Built-in trellis dialect — bundles all standard processors and filters.
class StandardDialect extends Dialect {
  @override
  String get name => 'Standard';

  @override
  List<Processor> get processors => [
    WithProcessor(),
    ObjectProcessor(),
    IfProcessor(),
    UnlessProcessor(),
    SwitchProcessor(),
    EachProcessor(),
    InsertProcessor(),
    ReplaceProcessor(),
    TextProcessor(),
    UtextProcessor(),
    InlineProcessor(),
    AttrProcessor(),
    RemoveProcessor(),
  ];

  @override
  Map<String, Function> get filters => const {
    'upper': _filterUpper,
    'lower': _filterLower,
    'trim': _filterTrim,
    'length': _filterLength,
  };

  static dynamic _filterUpper(dynamic v) => v?.toString().toUpperCase();
  static dynamic _filterLower(dynamic v) => v?.toString().toLowerCase();
  static dynamic _filterTrim(dynamic v) => v?.toString().trim();
  static dynamic _filterLength(dynamic v) =>
      v is Iterable ? v.length : (v?.toString().length ?? 0);
}
