import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/call_log_entry.dart';
import '../services/call_log_service.dart';
import '../services/contact_lookup_service.dart';

class CallLogScreen extends StatefulWidget {
  final void Function(String number) onCall;
  const CallLogScreen({super.key, required this.onCall});

  @override
  State<CallLogScreen> createState() => _CallLogScreenState();
}

class _CallLogScreenState extends State<CallLogScreen> {
  final _service = CallLogService();
  List<CallLogEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    CallLogService().notifier.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    CallLogService().notifier.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final entries = await _service.getAll();
    if (mounted) setState(() => _entries = entries);
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Napló törlése'),
        content: const Text('Biztosan törlöd az összes hívást?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Mégsem')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Törlés')),
        ],
      ),
    );
    if (ok == true) {
      await _service.clear();
      _load();
    }
  }

  void _confirmCall(BuildContext context, String name, String number) {
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
            if (name != number)
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

  IconData _icon(String direction) {
    switch (direction) {
      case 'outgoing': return Icons.call_made;
      case 'incoming': return Icons.call_received;
      default: return Icons.call_missed;
    }
  }

  Color _iconColor(String direction) {
    switch (direction) {
      case 'outgoing': return kBlue;
      case 'incoming': return kLime;
      default: return Colors.red;
    }
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}mp';
    return '${m}p ${s}mp';
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Tegnap';
    } else if (diff.inDays < 7) {
      const days = ['H', 'K', 'Sze', 'Cs', 'P', 'Szo', 'V'];
      return days[dt.weekday - 1];
    } else {
      return '${dt.month}.${dt.day}.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Még nincs hívás', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              itemCount: _entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (_, i) {
                final e = _entries[i];
                final name = ContactLookupService.instance.lookupName(e.number);
                return ListTile(
                  onTap: () => _confirmCall(context, name ?? e.number, e.number),
                  leading: CircleAvatar(
                    backgroundColor: _iconColor(e.direction).withOpacity(0.1),
                    child: Icon(_icon(e.direction), color: _iconColor(e.direction), size: 22),
                  ),
                  title: Text(
                    name ?? e.number,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (name != null)
                        Text(e.number, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      if (e.durationSeconds > 0)
                        Text(_formatDuration(e.durationSeconds),
                            style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_formatTime(e.timestamp),
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.call, color: kLime, size: 22),
                        onPressed: () => _confirmCall(context, name ?? e.number, e.number),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextButton.icon(
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Napló törlése'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ),
      ],
    );
  }
}
