import 'dart:math';

import 'contacts.dart';

const _pageSize = 8;
const _sortLabels = {'name': 'Name', 'email': 'Email', 'company': 'Company', 'status': 'Status'};

/// Normalizes request parameters once and builds the view and URLs for its current page.
final class ContactQuery {
  ContactQuery(Map<String, String> parameters, Iterable<Contact> contacts, {int? savedId})
    : q = parameters['q']?.trim() ?? '',
      status = statuses.containsKey(parameters['status']) ? parameters['status']! : '',
      sort = _sortLabels.containsKey(parameters['sort']) ? parameters['sort']! : 'name',
      dir = parameters['dir'] == 'desc' ? 'desc' : 'asc' {
    final text = q.toLowerCase();
    final matches = contacts.where((contact) {
      final draft = contact.draft;
      return (status.isEmpty || draft.status == status) &&
          [draft.name, draft.email, companies[draft.company]!].any((value) => value.toLowerCase().contains(text));
    }).toList()..sort(_compare);

    lastPage = max(1, (matches.length + _pageSize - 1) ~/ _pageSize);
    // Keep the current filters. If the save matches them, show its sorted page.
    final savedIndex = savedId == null ? -1 : matches.indexWhere((contact) => contact.id == savedId);
    page = savedIndex >= 0
        ? savedIndex ~/ _pageSize + 1
        : (int.tryParse(parameters['page'] ?? '') ?? 1).clamp(1, lastPage);
    rows = matches.skip((page - 1) * _pageSize).take(_pageSize).toList();
  }

  final String q;
  final String status;
  final String sort;
  final String dir;
  late final int page;
  late final int lastPage;
  late final List<Contact> rows;

  String url({String path = '/contacts', String? column, int? pageNumber}) => Uri(
    path: path,
    queryParameters: {
      'q': q,
      'status': status,
      'sort': column ?? sort,
      'dir': column == null ? dir : (sort == column && dir == 'asc' ? 'desc' : 'asc'),
      'page': '${pageNumber ?? page}',
    },
  ).toString();

  Map<String, Object?> toContext() => {
    'q': q,
    'status': status,
    'sort': sort,
    'dir': dir,
    'page': page,
    'statuses': [
      for (final entry in statuses.entries) {'value': entry.key, 'label': entry.value, 'selected': entry.key == status},
    ],
    'sortColumns': [
      for (final column in _sortLabels.entries)
        {
          'key': column.key,
          'label': column.value,
          'url': url(column: column.key, pageNumber: 1),
          'ariaSort': column.key != sort ? null : (dir == 'asc' ? 'ascending' : 'descending'),
        },
    ],
    'contacts': [
      for (final contact in rows)
        {
          'id': contact.id,
          'name': contact.draft.name,
          'email': contact.draft.email,
          'company': companies[contact.draft.company],
          'status': statuses[contact.draft.status],
          'statusVariant': switch (contact.draft.status) {
            'active' => 'default',
            'pending' => 'secondary',
            _ => 'outline',
          },
          'editUrl': url(path: '/contacts/${contact.id}/edit'),
          'deleteUrl': url(path: '/contacts/${contact.id}/delete'),
        },
    ],
    'empty': rows.isEmpty,
    'previous': page > 1 ? url(pageNumber: page - 1) : null,
    'next': page < lastPage ? url(pageNumber: page + 1) : null,
    'pages': [
      for (var number = 1; number <= lastPage; number++)
        {'label': number.toString(), 'href': url(pageNumber: number), 'current': number == page, 'ellipsis': false},
    ],
  };

  int _compare(Contact a, Contact b) {
    String sortValue(Contact contact) => switch (sort) {
      'email' => contact.draft.email,
      'company' => companies[contact.draft.company]!,
      'status' => statuses[contact.draft.status]!,
      _ => contact.draft.name,
    };

    final order = sortValue(a).toLowerCase().compareTo(sortValue(b).toLowerCase());
    return order == 0 ? a.id.compareTo(b.id) : (dir == 'asc' ? order : -order);
  }
}
