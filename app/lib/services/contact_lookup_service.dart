import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_contacts/models/permissions/permission_status.dart';
import 'package:flutter_contacts/models/permissions/permission_type.dart';
import 'contacts_service.dart';

class ContactLookupService {
  static final instance = ContactLookupService._();
  ContactLookupService._();

  final Map<String, String> _cache = {};
  bool _loaded = false;

  Future<void> load() async {
    _cache.clear();

    // Saját kontaktok (mindig elérhető)
    final appContacts = await ContactsService().getAll();
    for (final c in appContacts) {
      _cacheNumber(c.number, c.name);
    }

    // Rendszer kontaktok (ha már van engedély, ne kérjük újra)
    final status = await FlutterContacts.permissions.check(PermissionType.read);
    if (status == PermissionStatus.granted || status == PermissionStatus.limited) {
      final contacts = await FlutterContacts.getAll(properties: {ContactProperty.phone});
      for (final c in contacts) {
        for (final phone in c.phones) {
          _cacheNumber(phone.number, c.displayName ?? phone.number);
        }
      }
    }

    _loaded = true;
  }

  void _cacheNumber(String number, String name) {
    _cache[_normalize(number)] = name;
  }

  String? lookupName(String number) {
    if (!_loaded) return null;
    return _cache[_normalize(number)];
  }

  String _normalize(String n) => n.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
}
