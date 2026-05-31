import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/login_screen.dart';
import 'services/contact_lookup_service.dart';
import 'services/push_service.dart';
import 'services/sip_service.dart';
import 'app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ContactLookupService.instance.load();
  PushService().listenToCallKitEvents();
  _listenForPushReconnect();
  runApp(const SipApp());
}

void _listenForPushReconnect() {
  const MethodChannel('sip_reconnect').setMethodCallHandler((call) async {
    if (call.method == 'reconnect') {
      SipService().reconnect();
    }
  });
}

class SipApp extends StatelessWidget {
  const SipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIP Telefon',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const LoginScreen(),
    );
  }
}
