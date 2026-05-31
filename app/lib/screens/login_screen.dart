import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sip_service.dart';
import '../services/push_service.dart';
import 'home_screen.dart';
import 'package:sip_ua/sip_ua.dart';

const _blue = Color(0xFF1E5BB5);
const _blueDark = Color(0xFF153D80);
const _lime = Color(0xFF7CC042);
const _limeDark = Color(0xFF5E9A2E);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> implements SipUaHelperListener {
  final _serverCtrl = TextEditingController(text: 'wss://');
  final _domainCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    SipService().addListener(this);
    _loadSaved();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    SipService().removeListener(this);
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final server = prefs.getString('sip_server') ?? 'wss://';
    final domain = prefs.getString('sip_domain') ?? '';
    final user = prefs.getString('sip_user') ?? '';
    final password = prefs.getString('sip_password') ?? '';
    setState(() {
      _serverCtrl.text = server;
      _domainCtrl.text = domain;
      _userCtrl.text = user;
      _passCtrl.text = password;
    });
    // Ha minden ki van töltve, automatikusan csatlakozunk
    if (server.length > 6 && domain.isNotEmpty && user.isNotEmpty && password.isNotEmpty) {
      _connect();
    }
  }

  Future<void> _connect() async {
    setState(() { _loading = true; _error = null; });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sip_server', _serverCtrl.text.trim());
    await prefs.setString('sip_domain', _domainCtrl.text.trim());
    await prefs.setString('sip_user', _userCtrl.text.trim());
    await prefs.setString('sip_password', _passCtrl.text);

    _timeoutTimer = Timer(const Duration(seconds: 12), () {
      if (_loading && mounted) {
        _cancel(error: 'Időtúllépés — ellenőrizd a szerver címét és a portot');
      }
    });

    try {
      await SipService().connect(
        server: _serverCtrl.text.trim(),
        user: _userCtrl.text.trim(),
        password: _passCtrl.text,
        domain: _domainCtrl.text.trim(),
      );
    } catch (e) {
      _timeoutTimer?.cancel();
      if (mounted) setState(() { _loading = false; _error = 'Kapcsolódási hiba: $e'; });
    }
  }

  void _cancel({String? error}) {
    _timeoutTimer?.cancel();
    SipService().disconnect();
    if (mounted) setState(() { _loading = false; _error = error; });
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    if (!mounted) return;
    if (state.state == RegistrationStateEnum.REGISTERED) {
      _timeoutTimer?.cancel();
      setState(() => _loading = false);
      PushService().registerToken(_userCtrl.text.trim());
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(domain: _domainCtrl.text.trim())),
      );
    } else if (state.state == RegistrationStateEnum.REGISTRATION_FAILED) {
      _timeoutTimer?.cancel();
      setState(() {
        _loading = false;
        _error = 'Regisztráció sikertelen — ellenőrizd az adatokat';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_blueDark, _blue],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 48),
                // Logo lekerekített kerettel
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Image.asset('assets/logo.png', height: 72),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Mobil softphone',
                  style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1.2),
                ),
                const SizedBox(height: 40),
                // Form kártya
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(50),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Bejelentkezés',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _blueDark,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _FormField(
                          controller: _serverCtrl,
                          label: 'Szerver (WSS)',
                          hint: 'wss://szerver.hu:8089/ws',
                          icon: Icons.dns_outlined,
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 14),
                        _FormField(
                          controller: _domainCtrl,
                          label: 'SIP domain',
                          hint: 'szerver.hu',
                          icon: Icons.language_outlined,
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 14),
                        _FormField(
                          controller: _userCtrl,
                          label: 'Felhasználónév / mellékszám',
                          hint: '1001',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 14),
                        _FormField(
                          controller: _passCtrl,
                          label: 'Jelszó',
                          icon: Icons.lock_outline,
                          obscure: true,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              _error!,
                              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Csatlakozás gomb
                        ElevatedButton(
                          onPressed: _loading ? _cancel : _connect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _loading ? Colors.grey.shade400 : _lime,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: _loading ? 0 : 3,
                          ),
                          child: _loading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    SizedBox(
                                      height: 18, width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Mégsem', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  ],
                                )
                              : const Text('Csatlakozás', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen(domain: 'demo.local')),
                  ),
                  child: const Text(
                    'Demo mód megtekintése →',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override void callStateChanged(Call call, CallState state) {}
  @override void onNewMessage(SIPMessageRequest msg) {}
  @override void onNewNotify(Notify ntf) {}
  @override void onNewReinvite(ReInvite event) {}
  @override void transportStateChanged(TransportState state) {}
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;

  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _blue, size: 20),
        labelStyle: const TextStyle(color: Colors.black54, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _blue, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}
