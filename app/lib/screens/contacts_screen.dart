import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../app_theme.dart';
import 'package:flutter_contacts/models/permissions/permission_status.dart';
import 'package:flutter_contacts/models/permissions/permission_type.dart';
import '../models/app_contact.dart';
import '../services/contacts_service.dart';
import '../services/contact_lookup_service.dart';

class _ContactItem {
  final String name;
  final String number;
  final bool isSystem;
  final String? appId;

  _ContactItem({required this.name, required this.number, required this.isSystem, this.appId});
}

class ContactsScreen extends StatefulWidget {
  final void Function(String number) onCall;
  const ContactsScreen({super.key, required this.onCall});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _service = ContactsService();
  List<_ContactItem> _all = [];
  List<_ContactItem> _filtered = [];
  final _search = TextEditingController();
  bool _permissionDenied = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search.addListener(_filter);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = <_ContactItem>[];

    // Rendszer kontaktok
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    final hasPermission = status == PermissionStatus.granted || status == PermissionStatus.limited;
    if (hasPermission) {
      final contacts = await FlutterContacts.getAll(properties: {ContactProperty.phone});
      for (final c in contacts) {
        for (final phone in c.phones) {
          items.add(_ContactItem(
            name: c.displayName ?? c.phones.first.number,
            number: phone.number,
            isSystem: true,
          ));
        }
      }
    } else {
      setState(() => _permissionDenied = true);
    }

    // Saját kontaktok
    final appContacts = await _service.getAll();
    for (final c in appContacts) {
      items.add(_ContactItem(name: c.name, number: c.number, isSystem: false, appId: c.id));
    }

    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (mounted) {
      setState(() { _all = items; _loading = false; });
      _filter();
    }
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.of(_all)
          : _all.where((c) => c.name.toLowerCase().contains(q) || c.number.contains(q)).toList();
    });
  }

  Future<void> _addContact() async {
    final nameCtrl = TextEditingController();
    final numCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Új kontakt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Név')),
            const SizedBox(height: 12),
            TextField(controller: numCtrl, decoration: const InputDecoration(labelText: 'Telefonszám'),
                keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Mégsem')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Mentés')),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.isNotEmpty && numCtrl.text.isNotEmpty) {
      await _service.add(AppContact(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: nameCtrl.text.trim(),
        number: numCtrl.text.trim(),
      ));
      ContactLookupService.instance.load();
      _load();
    }
  }

  Future<void> _deleteContact(String id) async {
    await _service.delete(id);
    _load();
  }

  void _confirmCall(String name, String number) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text(number, style: const TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mégsem'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              widget.onCall(number);
            },
            icon: const Icon(Icons.call, size: 18),
            label: const Text('Hívás'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kLime,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Keresés…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              suffixIcon: _search.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _search.clear())
                  : null,
            ),
          ),
        ),
        if (_permissionDenied)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('Rendszer kontaktok: hozzáférés megtagadva',
                    style: TextStyle(fontSize: 13, color: Colors.orange))),
              ],
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.contacts, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(_search.text.isEmpty ? 'Még nincs kontakt' : 'Nincs találat',
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                      itemBuilder: (_, i) {
                        final c = _filtered[i];
                        return ListTile(
                          onTap: () => _confirmCall(c.name, c.number),
                          leading: CircleAvatar(
                            backgroundColor: c.isSystem
                                ? kLime.withAlpha(40)
                                : kBlue.withAlpha(30),
                            child: Text(_initials(c.name),
                                style: TextStyle(
                                  color: c.isSystem ? kLimeDark : kBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                )),
                          ),
                          title: Text(c.name),
                          subtitle: Text(c.number, style: const TextStyle(fontSize: 13)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.call, color: kLime, size: 22),
                                onPressed: () => _confirmCall(c.name, c.number),
                              ),
                              if (!c.isSystem && c.appId != null)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () => _deleteContact(c.appId!),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FloatingActionButton.extended(
            heroTag: 'contacts_add_fab',
            onPressed: _addContact,
            icon: const Icon(Icons.person_add),
            label: const Text('Új kontakt'),
          ),
        ),
      ],
    );
  }
}
