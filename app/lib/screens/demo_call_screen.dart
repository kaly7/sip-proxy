import 'package:flutter/material.dart';
import '../services/call_log_service.dart';
import '../models/call_log_entry.dart';
import '../widgets/audio_device_picker.dart';

enum _DemoState { ringing, connecting, active, ended }

class DemoCallScreen extends StatefulWidget {
  final String remote;
  final bool incoming;
  final bool startActive;
  final VoidCallback? onEnd;

  const DemoCallScreen({
    super.key,
    required this.remote,
    this.incoming = false,
    this.startActive = false,
    this.onEnd,
  });

  @override
  State<DemoCallScreen> createState() => _DemoCallScreenState();
}

class _DemoCallScreenState extends State<DemoCallScreen> with SingleTickerProviderStateMixin {
  _DemoState _state = _DemoState.ringing;
  bool _muted = false;
  bool _wasConnected = false;
  AudioDevice _audioDevice = AudioDevice.earpiece;
  Duration _elapsed = Duration.zero;
  DateTime? _connectedAt;
  bool _logSaved = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);

    if (widget.startActive) {
      _state = _DemoState.active;
      _connectedAt = DateTime.now();
      _startTimer();
    } else if (!widget.incoming) {
      _autoProgress();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    // Ha minimize-szal léptek ki és sosem akasztják le, mégis naplózzuk
    // (csak az "eredeti" képernyőnél, a startActive=true a visszatérős)
    if (!_logSaved && !widget.startActive) {
      final direction = _wasConnected
          ? (widget.incoming ? 'incoming' : 'outgoing')
          : (widget.incoming ? 'missed' : 'outgoing');
      _saveLog(direction);
    }
    super.dispose();
  }

  Future<void> _autoProgress() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    setState(() => _state = _DemoState.connecting);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _state = _DemoState.active;
      _connectedAt = DateTime.now();
      _wasConnected = true;
    });
    _startTimer();
  }

  Future<void> _answer() async {
    setState(() => _state = _DemoState.connecting);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _state = _DemoState.active;
      _connectedAt = DateTime.now();
      _wasConnected = true;
    });
    _startTimer();
  }

  void _hangup() {
    _saveLog(widget.incoming ? 'incoming' : 'outgoing');
    setState(() => _state = _DemoState.ended);
    widget.onEnd?.call();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }

  void _reject() {
    _saveLog('missed');
    setState(() => _state = _DemoState.ended);
    widget.onEnd?.call();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) Navigator.pop(context);
    });
  }

  void _saveLog(String direction) {
    if (_logSaved) return;
    _logSaved = true;
    CallLogService().add(CallLogEntry(
      number: widget.remote,
      direction: direction,
      timestamp: _connectedAt ?? DateTime.now(),
      durationSeconds: _elapsed.inSeconds,
    ));
  }

  void _showAudioDevicePicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => AudioDevicePicker(
        current: _audioDevice,
        demoMode: true,
        onSelect: (d) => setState(() => _audioDevice = d),
      ),
    );
  }

  void _showDialpad() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[850],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _InCallDialpad(),
    );
  }

  void _minimize() => Navigator.pop(context);

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (_connectedAt != null && _state == _DemoState.active) {
        setState(() => _elapsed = DateTime.now().difference(_connectedAt!));
      }
      return _state == _DemoState.active;
    });
  }

  String get _stateLabel {
    switch (_state) {
      case _DemoState.ringing:
        return widget.incoming ? 'Bejövő hívás' : 'Cseng…';
      case _DemoState.connecting: return 'Kapcsolódás…';
      case _DemoState.active: return _formatDuration(_elapsed);
      case _DemoState.ended: return 'Hívás vége';
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _isActive => _state == _DemoState.active;
  bool get _canMinimize => _isActive || _state == _DemoState.connecting ||
      (_state == _DemoState.ringing && !widget.incoming);

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
              // Fejléc
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
                    // Avatar + név
                    Column(
                      children: [
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, child) {
                            final scale = _state == _DemoState.ringing
                                ? 1.0 + _pulseCtrl.value * 0.08
                                : 1.0;
                            return Transform.scale(scale: scale, child: child);
                          },
                          child: const Icon(Icons.account_circle, size: 96, color: Colors.white54),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.remote,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w300,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _stateLabel,
                          style: TextStyle(
                            color: _isActive ? Colors.greenAccent : Colors.white54,
                            fontSize: 18,
                          ),
                        ),
                        if (_state == _DemoState.ringing && !widget.incoming) ...[
                          const SizedBox(height: 12),
                          _RingingDots(),
                        ],
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
                                  color: _muted ? Colors.orange : Colors.white24,
                                  onTap: () => setState(() => _muted = !_muted),
                                ),
                                const SizedBox(width: 32),
                                _CallBtn(
                                  icon: Icons.dialpad,
                                  label: 'Billentyűzet',
                                  color: Colors.white24,
                                  onTap: _showDialpad,
                                ),
                                const SizedBox(width: 32),
                                _CallBtn(
                                  icon: _audioDevice.icon,
                                  label: _audioDevice.label,
                                  color: _audioDevice != AudioDevice.earpiece
                                      ? Colors.blue.withAlpha(180)
                                      : Colors.white24,
                                  onTap: _showAudioDevicePicker,
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                          ],
                          if (_state == _DemoState.ended) ...[
                            const Icon(Icons.call_end, color: Colors.red, size: 48),
                            const SizedBox(height: 48),
                          ] else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_state == _DemoState.ringing && widget.incoming) ...[
                                  _RoundBtn(
                                    icon: Icons.call,
                                    color: Colors.green,
                                    size: 72,
                                    onTap: _answer,
                                  ),
                                  const SizedBox(width: 48),
                                ],
                                _RoundBtn(
                                  icon: Icons.call_end,
                                  color: Colors.red,
                                  size: 72,
                                  onTap: _state == _DemoState.ringing && widget.incoming
                                      ? _reject
                                      : _hangup,
                                ),
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
}

class _RingingDots extends StatefulWidget {
  @override
  State<_RingingDots> createState() => _RingingDotsState();
}

class _RingingDotsState extends State<_RingingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final t = (_ctrl.value - delay).clamp(0.0, 1.0);
            final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.2, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((opacity * 255).toInt()),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
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

class _InCallDialpad extends StatefulWidget {
  @override
  State<_InCallDialpad> createState() => _InCallDialpadState();
}

class _InCallDialpadState extends State<_InCallDialpad> {
  String _pressed = '';

  void _press(String digit) => setState(() => _pressed += digit);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(
            color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(
            _pressed.isEmpty ? ' ' : _pressed,
            style: const TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 6),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.6,
            children: [
              ...[
                ['1', ''], ['2', 'ABC'], ['3', 'DEF'],
                ['4', 'GHI'], ['5', 'JKL'], ['6', 'MNO'],
                ['7', 'PQRS'], ['8', 'TUV'], ['9', 'WXYZ'],
                ['*', ''], ['0', '+'], ['#', ''],
              ].map((d) => InkWell(
                onTap: () => _press(d[0]),
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(d[0], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w300)),
                    if (d[1].isNotEmpty)
                      Text(d[1], style: const TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 2)),
                  ],
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }
}
