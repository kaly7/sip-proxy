import 'dart:convert';
import 'dart:io';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'sip_service.dart';

class PushService {
  static final PushService _instance = PushService._internal();
  factory PushService() => _instance;
  PushService._internal();

  static const String _tokenApiUrl = 'http://192.168.16.22:9451/register-token';

  // Ha a felhasználó CallKit-en fogadott, mielőtt a SIP INVITE megérkezett volna
  bool pendingAnswer = false;

  Future<void> registerToken(String sipUser) async {
    if (!Platform.isIOS) return;
    await Future.delayed(const Duration(seconds: 1));
    final token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
    if (token == null || (token as String).isEmpty) return;

    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse(_tokenApiUrl));
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode({'user': sipUser, 'token': token}));
      await request.close();
      client.close();
      print('[PushService] VoIP token regisztrálva: $token');
    } catch (e) {
      print('[PushService] Token regisztráció sikertelen: $e');
    }
  }

  void listenToCallKitEvents() {
    FlutterCallkitIncoming.onEvent.listen((event) {
      if (event == null) return;
      switch (event.event) {
        case Event.actionCallAccept:
          final call = SipService().activeCall.value;
          if (call != null) {
            call.answer(SipService().buildCallOptions());
          } else {
            pendingAnswer = true;
          }
          break;
        case Event.actionCallDecline:
          SipService().activeCall.value?.hangup();
          pendingAnswer = false;
          break;
        case Event.actionCallEnded:
          SipService().activeCall.value?.hangup();
          pendingAnswer = false;
          break;
        default:
          break;
      }
    });
  }
}
