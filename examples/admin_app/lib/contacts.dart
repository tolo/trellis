/// The contacts API keeps its records in memory for the lifetime of one server.
final class ContactStore {
  ContactStore() : _contacts = {for (final (index, name) in _names.indexed) index + 1: _seed(index, name)};

  final Map<int, Contact> _contacts;
  int _nextId = _names.length + 1;

  Iterable<Contact> get contacts => _contacts.values;
  Contact? operator [](int? id) => _contacts[id];

  int save(ContactDraft draft, {int? id}) {
    final savedId = id ?? _nextId++;
    _contacts[savedId] = Contact(savedId, draft);
    return savedId;
  }

  void delete(int id) => _contacts.remove(id);

  /// Called after reading the body so the uniqueness check and save stay synchronous.
  Map<String, String> validate(ContactDraft draft, {int? editingId}) {
    final duplicateEmail = contacts.any(
      (contact) => contact.id != editingId && contact.draft.email.toLowerCase() == draft.email.toLowerCase(),
    );
    return {
      if (draft.name.isEmpty) 'name': 'Enter a name.',
      if (!_emailPattern.hasMatch(draft.email))
        'email': 'Enter a valid email address.'
      else if (duplicateEmail)
        'email': 'That email address already belongs to a contact.',
      if (!companies.containsKey(draft.company)) 'company': 'Choose a company from the suggestions.',
      if (!statuses.containsKey(draft.status)) 'status': 'Choose a status from the list.',
    };
  }
}

final class Contact {
  const Contact(this.id, this.draft);

  final int id;
  final ContactDraft draft;
}

final class ContactDraft {
  const ContactDraft({
    this.name = '',
    this.email = '',
    this.company = '',
    this.companyText = '',
    this.status = 'active',
  });

  factory ContactDraft.fromForm(Map<String, String> values) => ContactDraft(
    name: values['name']?.trim() ?? '',
    email: values['email']?.trim() ?? '',
    company: values['company'] ?? '',
    companyText: values['q']?.trim() ?? '',
    status: values['status'] ?? '',
  );

  final String name;
  final String email;
  final String company;
  final String companyText;
  final String status;
}

const companies = {'acme': 'Acme Studio', 'cobalt': 'Cobalt Systems', 'orbit': 'Orbit Works', 'river': 'River Labs'};

const statuses = {'active': 'Active', 'pending': 'Pending', 'archived': 'Archived'};

const _names = [
  'Ada Morgan',
  'Amir Shah',
  'Anika Rao',
  'Aria Chen',
  'Avery Ruiz',
  'Ben Nolan',
  'Camille Roy',
  'Daniel Kim',
  'Eden Ross',
  'Emilia Cruz',
  'Finn Patel',
  'Hana Ito',
  'Imani Cole',
  'Jules Marin',
  'Kai Park',
  'Leila Noor',
  'Luca Rossi',
  'Maya Singh',
  'Nina Soto',
  'Owen Clarke',
  'Riley Moss',
  'Sam Reed',
  'Zoe Lane',
];

Contact _seed(int index, String name) {
  final company = companies.keys.elementAt(index % companies.length);
  final mailbox = name.toLowerCase().replaceAll(' ', '.');
  return Contact(
    index + 1,
    ContactDraft(
      name: name,
      email: '$mailbox@example.${index < 18 ? 'test' : 'org'}',
      company: company,
      companyText: companies[company]!,
      status: index < 12 ? 'active' : (index < 19 ? 'pending' : 'archived'),
    ),
  );
}

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
