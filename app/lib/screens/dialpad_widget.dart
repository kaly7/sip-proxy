import 'package:flutter/material.dart';
import '../app_theme.dart';

class DialpadWidget extends StatefulWidget {
  final void Function(String number) onCall;
  const DialpadWidget({super.key, required this.onCall});

  @override
  State<DialpadWidget> createState() => _DialpadWidgetState();
}

class _DialpadWidgetState extends State<DialpadWidget> {
  String _number = '';

  void _press(String digit) => setState(() => _number += digit);
  void _delete() {
    if (_number.isNotEmpty) setState(() => _number = _number.substring(0, _number.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _number.isEmpty ? ' ' : _number,
            style: const TextStyle(fontSize: 36, letterSpacing: 4, color: kBlue, fontWeight: FontWeight.w300),
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
                heroTag: 'dialpad_call_fab',
                onPressed: _number.isEmpty ? null : () {
                  widget.onCall(_number);
                  setState(() => _number = '');
                },
                backgroundColor: _number.isEmpty ? Colors.grey.shade300 : kLime,
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
    );
  }
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
