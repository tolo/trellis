/// Generates the lib/counter_state.dart content for a Dart Frog + Trellis project.
///
/// Keeps the in-memory counter state in a shared library so the mutation routes
/// and the home page route stay in sync.
String dartFrogCounterStateTemplate(String projectName) =>
    'int _counter = 0;\n'
    '\n'
    'Map<String, dynamic> counterContext() => {\n'
    "  'count': _counter,\n"
    "  'isZero': _counter == 0,\n"
    '};\n'
    '\n'
    'Map<String, dynamic> homeContext() => {\n'
    "  'title': 'Home',\n"
    "  'pageTitle': 'Home — $projectName',\n"
    "  'appTitle': '$projectName',\n"
    '  ...counterContext(),\n'
    '  \'features\': [\n'
    '    {\n'
    '      \'name\': \'File-based routing\',\n'
    '      \'description\': \'Routes map to files, while shared counter state lives in lib/counter_state.dart.\',\n'
    '    },\n'
    '    {\n'
    '      \'name\': \'HTMX fragments\',\n'
    '      \'description\': \'Navigation swaps page-content, while mutations replace only the counter fragment.\',\n'
    '    },\n'
    '    {\n'
    '      \'name\': \'Template inheritance\',\n'
    '      \'description\': \'Layouts and pages share structure through tl:extends and tl:define.\',\n'
    '    },\n'
    '    {\n'
    '      \'name\': \'Security defaults\',\n'
    '      \'description\': \'Security headers, CSRF, and dev-mode hot reload are configured in app middleware.\',\n'
    '    },\n'
    '  ],\n'
    '};\n'
    '\n'
    'void incrementCounter() {\n'
    '  _counter++;\n'
    '}\n'
    '\n'
    'void decrementCounter() {\n'
    '  _counter--;\n'
    '}\n'
    '\n'
    'void resetCounter() {\n'
    '  _counter = 0;\n'
    '}\n';
