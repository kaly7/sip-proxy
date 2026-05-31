import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import '../services/sip_service.dart';
import 'call_screen.dart';
import 'demo_call_screen.dart';
import 'login_screen.dart';

class DialpadScreen extends StatefulWidget {
  final String domain;
  const DialpadScreen({super.key, required this.domain});

  @override
  State<DialpadScreen> createState() => _DialpadScreenState();
}

class _DialpadScreenState extends State<DialpadScreen> implements SipUaHelperListener {
  String _number = '';

  @override
  void initState() {
    super.initState();
    SipService().addListener(this);
  }

  @override
  void dispose() {
    SipService().removeListener(this);
    super.dispose();
  }

  void _press(String digit) => setState(() => _number += digit);
  void _delete() {
    if (_number.isNotEmpty) setState(() => _number = _number.substring(0, _number.length - 1));
  }

  void _call() {
    if (_number.isEmpty) return;
    SipService().call(_number, widget.domain);
  }

  void _logout() {
    SipService().disconnect();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  void callStateChanged(Call call, CallState state) {
    if (!mounted) return;
    if (state.state == CallStateEnum.CALL_INITIATION) {
      final remote = call.direction == 'INCOMING'
          ? (call.remote_identity ?? '?')
          : _number;
      setState(() => _number = '');
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CallScreen(call: call, remote: remote, domain: widget.domain),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hívás'),
        actions: [
          if (widget.domain == 'demo.local')
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DemoCallScreen(remote: 'Demo')),
              ),
              child: const Text('Demo hívás'),
            ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout, tooltip: 'Kijelentkezés'),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _number.isEmpty ? ' ' : _number,
              style: const TextStyle(fontSize: 36, letterSpacing: 4),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 48),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                ...[
                  ['1', ''], ['2', 'ABC'], ['3', 'DEF'],
                  ['4', 'GHI'], ['5', 'JKL'], ['6', 'MNO'],
                  ['7', 'PQRS'], ['8', 'TUV'], ['9', 'WXYZ'],
                  ['*', ''], ['0', '+'], ['#', ''],
                ].map((d) => _DialKey(
                  digit: d[0],
                  letters: d[1],
                  onTap: () => _press(d[0]),
                  onLongPress: d[0] == '0' ? () => _press('+') : null,
                )),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(width: 64),
                FloatingActionButton(
                  onPressed: _call,
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.call, size: 32),
                ),
                SizedBox(
                  width: 64,
                  child: _number.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.backspace_outlined),
                          onPressed: _delete,
                          iconSize: 28,
                        )
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override void registrationStateChanged(RegistrationState state) {}
  @override void onNewMessage(SIPMessageRequest msg) {}
  @override void onNewNotify(Notify ntf) {}
  @override void transportStateChanged(TransportState state) {}
  @override void onNewReinvite(ReInvite event) {}
}

class _DialKey extends StatelessWidget {
  final String digit;
  final String letters;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _DialKey({required this.digit, required this.letters, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(digit, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w300)),
          if (letters.isNotEmpty)
            Text(letters, style: const TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.grey)),
        ],
      ),
    );
  }
}
