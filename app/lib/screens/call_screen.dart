import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sip_ua/sip_ua.dart';
import '../services/sip_service.dart';
import '../services/call_log_service.dart';
import '../models/call_log_entry.dart';
import '../widgets/audio_device_picker.dart';

class CallScreen extends StatefulWidget {
  final Call call;
  final String remote;
  final String domain;

  const CallScreen({super.key, required this.call, required this.remote, required this.domain});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> implements SipUaHelperListener {
  CallStateEnum _state = CallStateEnum.NONE;
  bool _muted = false;
  AudioDevice _audioDevice = AudioDevice.earpiece;
  Duration _elapsed = Duration.zero;
  DateTime? _connectedAt;
  bool _wasConnected = false;
  final _logService = CallLogService();

  static const _proximity = MethodChannel('proximity_sensor');

  @override
  void initState() {
    super.initState();
    _proximity.invokeMethod('enable');
    SipService().addListener(this);
    SipService().activeCall.addListener(_onActiveCallChanged);
    _state = widget.call.state;
    if (SipService().callConnectedAt != null) {
      _connectedAt = SipService().callConnectedAt;
      _wasConnected = true;
      _elapsed = DateTime.now().difference(_connectedAt!);
      if (_state == CallStateEnum.CONFIRMED) _startTimer();
    }
    // Ha a hívás már véget ért mielőtt a screen felépült (pl. gyors visszautasítás),
    // a listener-ek már nem kapják meg az ENDED eseményt — itt kell bezárni.
    if (_state == CallStateEnum.ENDED ||
        _state == CallStateEnum.FAILED ||
        SipService().activeCall.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _close());
    }
  }

  @override
  void dispose() {
    _proximity.invokeMethod('disable');
    SipService().activeCall.removeListener(_onActiveCallChanged);
    SipService().removeListener(this);
    super.dispose();
  }

  void _onActiveCallChanged() {
    if (SipService().activeCall.value == null) _close();
  }

  void _hangup() {
    if (_isEnded) {
      // Hívás már véget ért — csak a képernyőt zárjuk be
      if (mounted) Navigator.pop(context);
      return;
    }
    try {
      widget.call.hangup({'status_code': 603});
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }
  void _answer() => widget.call.answer(SipService().buildCallOptions());

  void _minimize() => Navigator.pop(context);

  void _toggleMute() {
    setState(() => _muted = !_muted);
    if (_muted) {
      widget.call.mute(true, false);
    } else {
      widget.call.unmute(true, false);
    }
  }

  String get _stateLabel {
    switch (_state) {
      case CallStateEnum.CALL_INITIATION: return _isIncoming ? 'Bejövő hívás' : 'Cseng…';
      case CallStateEnum.CONNECTING: return 'Kapcsolódás…';
      case CallStateEnum.PROGRESS: return 'Hívás…';
      case CallStateEnum.ACCEPTED: return 'Kapcsolódva…';
      case CallStateEnum.CONFIRMED: return _formatDuration(_elapsed);
      case CallStateEnum.ENDED: return 'Hívás vége';
      case CallStateEnum.FAILED: return 'Sikertelen';
      default: return '…';
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool _closeStarted = false;

  void _close() {
    if (_closeStarted || !mounted) return;
    _closeStarted = true;
    _saveLog();
    final delay = _wasConnected ? const Duration(seconds: 2) : const Duration(milliseconds: 500);
    Future.delayed(delay, () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void callStateChanged(Call call, CallState state) {
    // Csak a saját hívás eseményeit kezeljük — más egyidejű hívás ne zavarja a UI-t
    final myId = widget.call.id;
    if (myId != null && myId.isNotEmpty && call.id != myId) return;
    if (!mounted) return;
    setState(() => _state = state.state);
    if (state.state == CallStateEnum.CONFIRMED) {
      _connectedAt = SipService().callConnectedAt ?? DateTime.now();
      _wasConnected = true;
      _startTimer();
    }
    if (state.state == CallStateEnum.ENDED || state.state == CallStateEnum.FAILED) {
      _close();
    }
  }

  void _showAudioDevicePicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => AudioDevicePicker(
        current: _audioDevice,
        demoMode: false,
        onSelect: (d) {
          setState(() => _audioDevice = d);
          applyAudioDevice(d);
        },
      ),
    );
  }

  void _saveLog() {
    if (widget.domain == 'demo.local') return;
    final direction = !_wasConnected && widget.call.direction == Direction.incoming
        ? 'missed'
        : widget.call.direction == Direction.incoming ? 'incoming' : 'outgoing';
    _logService.add(CallLogEntry(
      number: widget.call.remote_identity ?? widget.remote,
      direction: direction,
      timestamp: _connectedAt ?? DateTime.now(),
      durationSeconds: _elapsed.inSeconds,
    ));
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || _connectedAt == null) return false;
      setState(() => _elapsed = DateTime.now().difference(_connectedAt!));
      return _state == CallStateEnum.CONFIRMED;
    });
  }

  bool get _isIncoming => widget.call.direction == Direction.incoming;
  bool get _isActive => _state == CallStateEnum.CONFIRMED;
  bool get _isEnded => _state == CallStateEnum.ENDED || _state == CallStateEnum.FAILED;
  // Zöld gomb: bejövő hívás, még nem fogadva, még nem végzett
  bool get _isWaiting => _isIncoming && !_isActive && !_isEnded;
  bool get _canMinimize => _isActive || (!_isIncoming && _state != CallStateEnum.ENDED && _state != CallStateEnum.FAILED);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _canMinimize) _minimize();
      },
      child: Scaffold(
        backgroundColor: Colors.grey[900],
        body: SafeArea(
          child: Column(
            children: [
              // Fejléc — minimalizálás gomb
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    if (_canMinimize)
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 32),
                        onPressed: _minimize,
                        tooltip: 'Visszalépés (hívás folytatódik)',
                      ),
                    const Spacer(),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Névjegy
                    Column(
                      children: [
                        const Icon(Icons.account_circle, size: 96, color: Colors.white54),
                        const SizedBox(height: 16),
                        Text(
                          widget.remote,
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w300),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _stateLabel,
                          style: TextStyle(
                            color: _state == CallStateEnum.CONFIRMED ? Colors.greenAccent : Colors.white54,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    // Gombok
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          if (_isActive) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _CallBtn(
                                  icon: _muted ? Icons.mic_off : Icons.mic,
                                  label: _muted ? 'Némítva' : 'Mikrofon',
                                  onTap: _toggleMute,
                                  color: _muted ? Colors.orange : Colors.white24,
                                ),
                                const SizedBox(width: 32),
                                _CallBtn(
                                  icon: _audioDevice.icon,
                                  label: _audioDevice.label,
                                  onTap: _showAudioDevicePicker,
                                  color: _audioDevice != AudioDevice.earpiece
                                      ? Colors.blue.withAlpha(180)
                                      : Colors.white24,
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isWaiting) ...[
                                _LabeledBtn(icon: Icons.call_end, color: Colors.red, size: 72, label: 'Elutasítás', onTap: _hangup),
                                const SizedBox(width: 48),
                                _LabeledBtn(icon: Icons.call, color: Colors.green, size: 72, label: 'Fogadás', onTap: _answer),
                              ] else ...[
                                _RoundBtn(icon: Icons.call_end, color: Colors.red, size: 72, onTap: _hangup),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override void registrationStateChanged(RegistrationState state) {}
  @override void onNewMessage(SIPMessageRequest msg) {}
  @override void onNewNotify(Notify ntf) {}
  @override void onNewReinvite(ReInvite event) {}
  @override void transportStateChanged(TransportState state) {}
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _RoundBtn({required this.icon, required this.color, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * 0.45),
      ),
    );
  }
}

class _LabeledBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final String label;
  final VoidCallback onTap;

  const _LabeledBtn({required this.icon, required this.color, required this.size, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size, height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: size * 0.45),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

class _CallBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}
