import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import '../app_theme.dart';
import '../services/sip_service.dart';
import '../services/contact_lookup_service.dart';
import 'call_screen.dart';
import 'demo_call_screen.dart';
import 'call_log_screen.dart';
import 'contacts_screen.dart';
import 'dialpad_widget.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String domain;
  const HomeScreen({super.key, required this.domain});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> implements SipUaHelperListener {
  int _tab = 0;
  String? _demoCallRemote;
  bool _callScreenActive = false;
  _SipLifecycleObserver? _lifecycleObserver;

  bool get _isDemo => widget.domain == 'demo.local';

  @override
  void initState() {
    super.initState();
    if (!_isDemo) {
      SipService().addListener(this);
      ContactLookupService.instance.load();
      _lifecycleObserver = _SipLifecycleObserver();
      WidgetsBinding.instance.addObserver(_lifecycleObserver!);
    }
  }

  @override
  void dispose() {
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
    }
    SipService().removeListener(this);
    super.dispose();
  }

  // --- Éles hívás ---

  void _call(String number) {
    if (_isDemo) {
      _callDemo(number);
      return;
    }
    if (!SipService().isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nincs aktív SIP kapcsolat — jelentkezz be újra'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final name = ContactLookupService.instance.lookupName(number);
    SipService().activeCallRemote = name ?? number;
    SipService().call(number, widget.domain);
  }

  void _logout() {
    if (!_isDemo) SipService().disconnect();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _openCallScreen() {
    final call = SipService().activeCall.value;
    if (call == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CallScreen(
        call: call,
        remote: SipService().activeCallRemote,
        domain: widget.domain,
      ),
    ));
  }

  @override
  void callStateChanged(Call call, CallState state) {
    if (!mounted) return;
    if (state.state == CallStateEnum.CALL_INITIATION) {
      if (_callScreenActive) {
        try { call.hangup({'status_code': 486}); } catch (_) {}
        return;
      }
      _callScreenActive = true;
      // Biztonsági reset: ha a képernyő nem nyílt meg rendesen (pl. background), 10mp után feloldjuk
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && _callScreenActive && SipService().activeCall.value == null) {
          setState(() => _callScreenActive = false);
        }
      });
      final identity = call.remote_identity ?? '?';
      final displayName = call.remote_display_name;
      final name = call.direction == Direction.incoming
          ? (ContactLookupService.instance.lookupName(identity) ?? displayName ?? identity)
          : SipService().activeCallRemote;
      SipService().activeCallRemote = name;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CallScreen(call: call, remote: name, domain: widget.domain),
      )).then((_) {
        if (mounted) setState(() => _callScreenActive = false);
      });
    } else if (state.state == CallStateEnum.ENDED || state.state == CallStateEnum.FAILED) {
      // Közvetlen reset ha a call véget ért — ne maradjon stuck
      if (mounted) setState(() => _callScreenActive = false);
    }
  }

  // --- Demo hívás ---

  void _callDemo(String number) {
    setState(() => _demoCallRemote = number);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DemoCallScreen(
        remote: number,
        incoming: false,
        onEnd: () { if (mounted) setState(() => _demoCallRemote = null); },
      ),
    ));
  }

  void _triggerIncomingDemo() {
    const fakeCallers = ['+36 30 456 7890', 'Kovács Béla', '+36 20 111 2233', 'Nagy Anikó'];
    final remote = fakeCallers[DateTime.now().second % fakeCallers.length];
    setState(() => _demoCallRemote = remote);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DemoCallScreen(
        remote: remote,
        incoming: true,
        onEnd: () { if (mounted) setState(() => _demoCallRemote = null); },
      ),
    ));
  }

  void _returnToDemoCall() {
    if (_demoCallRemote == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DemoCallScreen(
        remote: _demoCallRemote!,
        incoming: false,
        startActive: true,
        onEnd: () { if (mounted) setState(() => _demoCallRemote = null); },
      ),
    ));
  }

  static const _titles = ['Tárcsázó', 'Hívásnapló', 'Kontaktok'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBarLogo(),
        actions: [
          if (_isDemo)
            IconButton(
              icon: const Icon(Icons.add_ic_call),
              onPressed: _demoCallRemote == null ? _triggerIncomingDemo : null,
              tooltip: 'Bejövő hívás szimulálása',
            ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout, tooltip: 'Kijelentkezés'),
        ],
      ),
      body: Column(
        children: [
          // Éles aktív hívás banner
          if (!_isDemo)
            ValueListenableBuilder<Call?>(
              valueListenable: SipService().activeCall,
              builder: (_, call, __) {
                if (call == null) return const SizedBox.shrink();
                return _ActiveCallBanner(
                  remote: SipService().activeCallRemote,
                  onTap: _openCallScreen,
                );
              },
            ),
          // Demo aktív hívás banner
          if (_isDemo && _demoCallRemote != null)
            _DemoCallBanner(
              remote: _demoCallRemote!,
              onTap: _returnToDemoCall,
            ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                DialpadWidget(onCall: _call),
                CallLogScreen(onCall: _call),
                ContactsScreen(onCall: _call),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dialpad), label: 'Tárcsázó'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Napló'),
          BottomNavigationBarItem(icon: Icon(Icons.contacts), label: 'Kontaktok'),
        ],
      ),
    );
  }

  @override void registrationStateChanged(RegistrationState state) {}
  @override void onNewMessage(SIPMessageRequest msg) {}
  @override void onNewNotify(Notify ntf) {}
  @override void onNewReinvite(ReInvite event) {}
  @override void transportStateChanged(TransportState state) {}

}

// --- Bannerek ---

class _ActiveCallBanner extends StatefulWidget {
  final String remote;
  final VoidCallback onTap;
  const _ActiveCallBanner({required this.remote, required this.onTap});

  @override
  State<_ActiveCallBanner> createState() => _ActiveCallBannerState();
}

class _ActiveCallBannerState extends State<_ActiveCallBanner> {
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    final connectedAt = SipService().callConnectedAt;
    if (connectedAt != null) {
      _elapsed = DateTime.now().difference(connectedAt);
      _startTimer();
    }
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      final connectedAt = SipService().callConnectedAt;
      if (connectedAt == null) return false;
      setState(() => _elapsed = DateTime.now().difference(connectedAt));
      return SipService().activeCall.value != null;
    });
  }

  String get _timer {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) => _CallBannerWidget(
    remote: widget.remote,
    trailing: SipService().callConnectedAt != null ? _timer : null,
    onTap: widget.onTap,
  );
}

class _DemoCallBanner extends StatelessWidget {
  final String remote;
  final VoidCallback onTap;
  const _DemoCallBanner({required this.remote, required this.onTap});

  @override
  Widget build(BuildContext context) => _CallBannerWidget(
    remote: remote,
    trailing: null,
    onTap: onTap,
  );
}

class _CallBannerWidget extends StatelessWidget {
  final String remote;
  final String? trailing;
  final VoidCallback onTap;

  const _CallBannerWidget({required this.remote, required this.trailing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        color: kLime,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.call, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                remote,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null)
              Text(trailing!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SipLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Push reconnect után 30 mp grace period — ne szakítsuk meg azonnal
      if (!SipService().inKeepAlive) {
        SipService().disconnect();
      }
    } else if (state == AppLifecycleState.resumed) {
      SipService().reconnect();
    }
  }
}
