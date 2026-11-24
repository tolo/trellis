import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_shelf/trellis_shelf.dart';
import 'package:trellis_ui/trellis_ui.dart';

import 'contact_query.dart';
import 'contacts.dart';

/// Builds an independent contacts app rooted at the supplied deployment directory.
({Handler handler, Future<void> Function() close}) createAdminApp(Directory root, {required String csrfSecret}) {
  final engine = Trellis(loader: CompositeLoader([FileSystemLoader('${root.path}/templates'), TrellisUiLoader()]));
  final contacts = _Contacts(ContactStore());
  final router = Router()
    ..get('/', contacts.list)
    ..get('/contacts', contacts.list)
    ..get('/contacts/new', contacts.createDialog)
    ..get('/contacts/<id|[0-9]+>/edit', contacts.editDialog)
    ..get('/contacts/<id|[0-9]+>/delete', contacts.deleteDialog)
    ..post('/contacts', contacts.create)
    ..put('/contacts/<id|[0-9]+>', contacts.update)
    ..delete('/contacts/<id|[0-9]+>', contacts.delete)
    ..get('/companies', contacts.suggestCompanies);

  final filesAndRoutes = Cascade().add(createStaticHandler('${root.path}/static')).add(router.call).handler;
  final handler = const Pipeline()
      .addMiddleware(
        trellisSecurityHeaders(
          csp: const CspBuilder.strict(baseUri: "'none'", connectSrc: "'self'", fontSrc: "'self' data:"),
        ),
      )
      .addMiddleware(trellisEngine(engine))
      .addMiddleware(trellisCsrf(secret: csrfSecret))
      .addHandler((request) {
        final asset = trellisUiRespond(request.requestedUri.path, ifNoneMatch: request.headers['if-none-match']);
        if (asset != null) {
          return Response(asset.statusCode, body: asset.body, headers: asset.headers);
        }
        return filesAndRoutes(request);
      });
  return (handler: handler, close: engine.close);
}

final class _Contacts {
  const _Contacts(this.store);

  final ContactStore store;

  ContactQuery _query(Request request, {int? savedId}) =>
      ContactQuery(request.requestedUri.queryParameters, store.contacts, savedId: savedId);

  List<Map<String, Object>> get _summary => [
    for (final status in statuses.entries)
      {
        'key': status.key,
        'label': status.value,
        'count': store.contacts.where((contact) => contact.draft.status == status.key).length,
      },
  ];

  Future<Response> list(Request request) async {
    const vary = 'HX-Request, HX-History-Restore-Request, HX-Trigger';
    final query = _query(request);
    final context = {...query.toContext(), 'summary': _summary, 'summaryOob': false, 'preserveFilter': false};
    if (isHtmxRequest(request) && request.headers['hx-history-restore-request'] != 'true') {
      final result = await renderFragment(request, 'list', 'list', {
        ...context,
        'preserveFilter': request.headers['hx-trigger'] == 'contact-filter',
      });
      return result.change(headers: {'HX-Push-Url': query.url(), 'Vary': vary});
    }
    final result = await renderPage(request, 'contacts', context);
    return result.change(headers: {'Vary': vary});
  }

  Future<Response> createDialog(Request request) => _form(request, const ContactDraft());

  Future<Response> editDialog(Request request, String id) async {
    final contact = store[int.tryParse(id)];
    if (contact == null) return Response.notFound('Contact not found');
    return _form(request, contact.draft, id: contact.id);
  }

  Future<Response> deleteDialog(Request request, String id) async {
    final contact = store[int.tryParse(id)];
    if (contact == null) return Response.notFound('Contact not found');
    return renderFragment(request, 'dialog', 'delete', {
      'dialogId': 'delete-$id',
      'title': 'Delete ${contact.draft.name}?',
      'returnFocus': 'actions-$id-trigger',
      'url': _query(request).url(path: '/contacts/$id'),
    });
  }

  Future<Response> _form(Request request, ContactDraft draft, {int? id, Map<String, String> errors = const {}}) =>
      renderFragment(request, 'dialog', 'form', {
        'editing': id != null,
        'dialogId': id == null ? 'new-contact-dialog' : 'edit-$id',
        'title': id == null ? 'New contact' : 'Edit contact',
        'returnFocus': id == null ? 'new-contact' : 'actions-$id-trigger',
        'url': _query(request).url(path: id == null ? '/contacts' : '/contacts/$id'),
        'name': draft.name,
        'email': draft.email,
        'appointmentDate': draft.appointmentDate,
        'rangeStart': draft.rangeStart,
        'rangeEnd': draft.rangeEnd,
        'companyId': draft.company,
        'companyText': companies[draft.company] ?? draft.companyText,
        'options': _companyOptions(''),
        'statuses': [
          for (final entry in statuses.entries)
            {'value': entry.key, 'label': entry.value, 'selected': entry.key == draft.status},
        ],
        'errors': errors,
        'focus': errors.isEmpty ? 'name' : errors.keys.first,
      });

  Future<Response> create(Request request) => _save(request);

  Future<Response> update(Request request, String id) => _save(request, id: id);

  Future<Response> _save(Request request, {String? id}) async {
    final fields = await _readForm(request);
    final existingId = id == null ? null : int.tryParse(id);
    if (id != null && store[existingId] == null) return Response.notFound('Contact not found');
    if (fields == null) return Response.badRequest(body: 'Malformed contact form');
    final draft = ContactDraft.fromForm(fields);
    final errors = store.validate(draft, editingId: existingId);
    if (errors.isNotEmpty) return _form(request, draft, id: existingId, errors: errors);
    final savedId = store.save(draft, id: existingId);
    return _mutation(request, id == null ? 'Contact created' : 'Contact updated', draft.name, savedId: savedId);
  }

  Future<Map<String, String>?> _readForm(Request request) async {
    try {
      return Uri.splitQueryString(await request.readAsString());
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  Future<Response> delete(Request request, String id) async {
    final contact = store[int.tryParse(id)];
    if (contact == null) return Response.notFound('Contact not found');
    store.delete(contact.id);
    return _mutation(request, 'Contact deleted', contact.draft.name);
  }

  Future<Response> _mutation(Request request, String title, String name, {int? savedId}) async {
    final query = _query(request, savedId: savedId);
    final context = {...query.toContext(), 'summary': _summary, 'summaryOob': true, 'preserveFilter': false};
    final engine = getEngine(request);
    final list = await engine.renderFileFragment('list', fragment: 'list', context: context);
    final summary = await engine.renderFileFragment('summary', fragment: 'summary', context: context);
    final host = await engine.renderFileFragment('dialog', fragment: 'clear', context: const {});
    final toast = await engine.renderFileFragment(
      'trellis-ui/toast',
      fragment: 'toast',
      context: {'type': 'success', 'title': title, 'description': name, 'duration': 6000, 'outOfBand': true},
    );
    return htmlResponse('$list$host$summary$toast').change(
      headers: {
        'HX-Retarget': '#contact-list',
        // On narrow screens the replacement scroller must reveal the restored row action.
        'HX-Reswap': 'outerHTML focus-scroll:true',
        'HX-Push-Url': query.url(),
      },
    );
  }

  Future<Response> suggestCompanies(Request request) => renderFragment(
    request,
    'trellis-ui/combobox',
    'comboboxOptions',
    {'id': 'contact-company', 'options': _companyOptions(request.requestedUri.queryParameters['q'] ?? '')},
  );

  List<Map<String, String>> _companyOptions(String text) => [
    for (final company in companies.entries)
      if (company.value.toLowerCase().contains(text.trim().toLowerCase()))
        {'value': company.key, 'label': company.value},
  ];
}
