import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sip_ua/sip_ua.dart';
import 'push_service.dart';

class SipService implements SipUaHelperListener {
  static final SipService _instance = SipService._internal();
  factory SipService() => _instance;
  SipService._internal();

  final SIPUAHelper _helper = SIPUAHelper();
  final List<SipUaHelperListener> _listeners = [];

  // Aktív hívás állapota — a banner és a visszatérés gomb erre figyel
  final activeCall = ValueNotifier<Call?>(null);
  String activeCallRemote = '';
  String activeDomain = '';
  DateTime? callConnectedAt;

  // Utolsó credentials — reconnect()-hez
  String _lastServer = '';
  String _lastUser = '';
  String _lastPassword = '';
  String _lastDomain = '';

  // Push reconnect után ne disconnecteljünk azonnal (30 mp grace period)
  DateTime? _keepAliveUntil;

  bool get inKeepAlive =>
      _keepAliveUntil != null && DateTime.now().isBefore(_keepAliveUntil!);

  void addListener(SipUaHelperListener l) => _listeners.add(l);
  void removeListener(SipUaHelperListener l) => _listeners.remove(l);

  Future<void> reconnect() async {
    // Ha nincs memóriában credential (app újraindult), betöltjük SharedPreferences-ből
    if (_lastServer.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      _lastServer = prefs.getString('sip_server') ?? '';
      _lastUser = prefs.getString('sip_user') ?? '';
      _lastPassword = prefs.getString('sip_password') ?? '';
      _lastDomain = prefs.getString('sip_domain') ?? '';
    }
    if (_lastServer.isEmpty || _lastPassword.isEmpty) return;
    _keepAliveUntil = DateTime.now().add(const Duration(seconds: 30));
    await connect(
      server: _lastServer,
      user: _lastUser,
      password: _lastPassword,
      domain: _lastDomain,
    );
  }

  Future<void> connect({
    required String server,
    required String user,
    required String password,
    required String domain,
  }) async {
    _lastServer = server;
    _lastUser = user;
    _lastPassword = password;
    _lastDomain = domain;
    activeDomain = domain;
    _helper.addSipUaHelperListener(this);

    final settings = UaSettings();
    settings.transportType = TransportType.WS;
    settings.webSocketUrl = server;
    settings.webSocketSettings.allowBadCertificate = true;
    settings.uri = 'sip:$user@$domain';
    settings.authorizationUser = user;
    settings.password = password;
    settings.displayName = user;
    settings.userAgent = 'SipApp/1.0';

    await _helper.start(settings);
  }

  void disconnect() {
    activeCall.value = null;
    activeCallRemote = '';
    _helper.stop();
  }

  void call(String target, String domain) {
    _helper.call('sip:$target@$domain', voiceOnly: true);
  }

  Map<String, dynamic> buildCallOptions() => _helper.buildCallOptions(true);

  bool get isConnected => _helper.registered;

  void _checkPendingAnswer(Call call) {
    if (PushService().pendingAnswer) {
      PushService().pendingAnswer = false;
      Future.delayed(const Duration(milliseconds: 300), () {
        call.answer(buildCallOptions());
      });
    }
  }

  // --- SipUaHelperListener ---

  @override
  void registrationStateChanged(RegistrationState state) {
    for (final l in List.of(_listeners)) {
      l.registrationStateChanged(state);
    }
  }

  @override
  void callStateChanged(Call call, CallState state) {
    if (state.state == CallStateEnum.CALL_INITIATION) {
      activeCall.value = call;
      // Ha a user már fogadott CallKit-en push előtt, auto-answer
      if (call.direction == Direction.incoming) {
        _checkPendingAnswer(call);
      }
    } else if (state.state == CallStateEnum.CONFIRMED) {
      callConnectedAt = DateTime.now();
    } else if (state.state == CallStateEnum.ENDED || state.state == CallStateEnum.FAILED) {
      activeCall.value = null;
      activeCallRemote = '';
      callConnectedAt = null;
      // CallKit UI bezárása ha a SIP session véget ért (pl. BYE érkezett)
      FlutterCallkitIncoming.endAllCalls();
    }
    for (final l in List.of(_listeners)) {
      l.callStateChanged(call, state);
    }
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {
    for (final l in List.of(_listeners)) {
      l.onNewMessage(msg);
    }
  }

  @override
  void onNewNotify(Notify ntf) {
    for (final l in List.of(_listeners)) {
      l.onNewNotify(ntf);
    }
  }

  @override
  void transportStateChanged(TransportState state) {
    for (final l in List.of(_listeners)) {
      l.transportStateChanged(state);
    }
  }

  @override
  void onNewReinvite(ReInvite event) {
    for (final l in List.of(_listeners)) {
      l.onNewReinvite(event);
    }
  }
}
