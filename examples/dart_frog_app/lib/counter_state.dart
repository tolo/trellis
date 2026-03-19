int _counter = 0;

Map<String, dynamic> counterContext() => {'count': _counter, 'isZero': _counter == 0};

Map<String, dynamic> homeContext() => {
  'title': 'Home',
  'pageTitle': 'Home — Trellis + Dart Frog',
  'appTitle': 'Trellis + Dart Frog',
  ...counterContext(),
  'features': [
    {
      'name': 'File-based routing',
      'description': 'Routes map to files, while shared counter state lives in lib/counter_state.dart.',
    },
    {
      'name': 'HTMX fragments',
      'description': 'Navigation swaps page-content, while mutations replace only the counter fragment.',
    },
    {
      'name': 'Template inheritance',
      'description': 'Layouts and pages share structure through tl:extends and tl:define.',
    },
    {
      'name': 'Security defaults',
      'description': 'Security headers, CSRF, and dev-mode hot reload are configured in app middleware.',
    },
  ],
};

void incrementCounter() {
  _counter++;
}

void decrementCounter() {
  _counter--;
}

void resetCounter() {
  _counter = 0;
}
