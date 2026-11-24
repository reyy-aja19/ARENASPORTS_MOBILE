import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/pin_service.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hasPin = await PinService.instance.hasPin();
    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _oldPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final oldPin = _oldPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (_hasPin) {
      if (oldPin.length < 4) {
        _show('Masukkan PIN lama Anda.', Colors.orange);
        return;
      }
      final validOld = await PinService.instance.verifyPin(oldPin);
      if (!validOld) {
        _show('PIN lama tidak sesuai.', Colors.red);
        return;
      }
    }

    if (newPin.length < 4 || newPin.length > 6) {
      _show('PIN baru harus 4-6 digit.', Colors.orange);
      return;
    }
    if (!RegExp(r'^\d+$').hasMatch(newPin)) {
      _show('PIN hanya boleh berisi angka.', Colors.orange);
      return;
    }
    if (newPin != confirmPin) {
      _show('Konfirmasi PIN tidak sama.', Colors.orange);
      return;
    }

    setState(() => _saving = true);
    try {
      await PinService.instance.setPin(newPin);
      if (!mounted) return;
      _show(_hasPin ? 'PIN berhasil diubah.' : 'PIN berhasil dibuat.', Colors.green);
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _show(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(_hasPin ? 'Ubah PIN' : 'Buat PIN'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E2A2B),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasPin
                          ? 'Masukkan PIN lama, lalu buat PIN baru untuk keamanan akun Anda.'
                          : 'Buat PIN 4-6 digit untuk keamanan dan quick login.',
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 20),
                    if (_hasPin) ...[
                      _pinField(
                        controller: _oldPinController,
                        label: 'PIN Lama',
                      ),
                      const SizedBox(height: 14),
                    ],
                    _pinField(
                      controller: _newPinController,
                      label: 'PIN Baru',
                    ),
                    const SizedBox(height: 14),
                    _pinField(
                      controller: _confirmPinController,
                      label: 'Konfirmasi PIN Baru',
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A32A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(_saving ? 'Menyimpan...' : 'Simpan PIN'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _pinField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
