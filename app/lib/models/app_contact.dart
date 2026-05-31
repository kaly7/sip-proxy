class AppContact {
  final String id;
  final String name;
  final String number;

  AppContact({required this.id, required this.name, required this.number});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'number': number};

  factory AppContact.fromJson(Map<String, dynamic> j) => AppContact(
    id: j['id'] as String,
    name: j['name'] as String,
    number: j['number'] as String,
  );
}
