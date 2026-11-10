import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../dashboard/dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _emerald = Color(0xFF18776A);
  static const _slate = Color(0xFF172D36);
  static const _ivory = Color(0xFFF5F6F2);
  static const _muted = Color(0xFF617178);
  static const _border = Color(0xFFE4E9E5);
  static const _red = Color(0xFFC54648);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_loading || !(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await AuthService.register({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passCtrl.text,
        'phone': _phoneCtrl.text.trim(),
      });
      if (res['success'] == true) {
        await AuthService.saveToken(res['data']['token'], res['data']['user']);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else if (mounted) {
        setState(() => _error = res['message']?.toString() ??
            'Registrasi gagal. Silakan coba lagi.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Belum dapat membuat akun. Periksa koneksi internet dan coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Masukkan alamat email Anda.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Periksa kembali format alamat email.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ivory,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 960;
          final padding = wide ? 48.0 : 20.0;
          final minHeight = constraints.maxHeight - padding * 2;
          return SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: minHeight > 0 ? minHeight : 0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: _introduction(context)),
                            const SizedBox(width: 32),
                            Expanded(child: _formCard(context, wide: true)),
                          ],
                        )
                      : Column(
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                    color: _slate,
                                    borderRadius: BorderRadius.circular(22)),
                                child: _brand(context),
                              ),
                            ),
                            const SizedBox(height: 20),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: _formCard(context, wide: false),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _brand(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: _emerald, borderRadius: BorderRadius.circular(14)),
          child:
              const Icon(Icons.shield_outlined, color: Colors.white, size: 25),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('KomplekGuard',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    )),
            const SizedBox(height: 3),
            Text('Warga terhubung. Lingkungan terjaga.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: const Color(0xFFD3E5DF), fontSize: 11)),
          ],
        )),
      ],
    );
  }

  Widget _introduction(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(36),
      decoration:
          BoxDecoration(color: _slate, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _brand(context),
          const SizedBox(height: 56),
          Text('Mulai dari saling kenal.\nTumbuh jadi saling jaga.',
              style: textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                fontSize: 36,
                height: 1.2,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.1,
              )),
          const SizedBox(height: 20),
          Text(
              'Bergabung untuk mengikuti laporan lingkungan dan ikut membantu saat warga membutuhkan.',
              style: textTheme.bodyMedium
                  ?.copyWith(color: const Color(0xFFD3E5DF), height: 1.7)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                color: const Color(0xFF27494C),
                borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.people_outline_rounded,
                    color: Color(0xFFC3E9D9), size: 32),
                const SizedBox(height: 16),
                Text('Kepedulian Anda berarti.',
                    style: textTheme.titleMedium?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                    'Sebuah laporan, informasi lokasi, atau respons bantuan bisa menjadi awal lingkungan yang lebih terhubung.',
                    style: textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFD3E5DF), height: 1.7)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formCard(BuildContext context, {required bool wide}) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(wide ? 36 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x07172D36), blurRadius: 32, offset: Offset(0, 12))
        ],
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BERGABUNG BERSAMA WARGA',
                  style: textTheme.labelSmall?.copyWith(
                    color: _emerald,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  )),
              const SizedBox(height: 12),
              Text('Buat akun Anda',
                  style: textTheme.headlineSmall?.copyWith(
                    color: _slate,
                    fontSize: wide ? 30 : 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  )),
              const SizedBox(height: 10),
              Text(
                  'Langkah kecil untuk lebih terhubung dengan lingkungan Anda.',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: _muted, height: 1.6)),
              const SizedBox(height: 28),
              if (_error != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Container(
                    key: const Key('register_error'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFBEFEE),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: _red, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(_error!,
                                  style: textTheme.bodySmall
                                      ?.copyWith(color: _red, height: 1.5))),
                        ]),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              TextFormField(
                key: const Key('register_name'),
                controller: _nameCtrl,
                enabled: !_loading,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Masukkan nama lengkap Anda.'
                    : null,
                decoration:
                    _decoration('Nama lengkap', Icons.person_outline_rounded),
              ),
              const SizedBox(height: 18),
              TextFormField(
                key: const Key('register_email'),
                controller: _emailCtrl,
                enabled: !_loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                validator: _validateEmail,
                decoration: _decoration('Email', Icons.mail_outline_rounded),
              ),
              const SizedBox(height: 18),
              TextFormField(
                key: const Key('register_phone'),
                controller: _phoneCtrl,
                enabled: !_loading,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: _decoration('Nomor telepon', Icons.phone_outlined)
                    .copyWith(helperText: 'Opsional'),
              ),
              const SizedBox(height: 18),
              TextFormField(
                key: const Key('register_password'),
                controller: _passCtrl,
                enabled: !_loading,
                obscureText: _obscurePassword,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _register(),
                validator: (value) => value == null || value.isEmpty
                    ? 'Buat kata sandi untuk akun Anda.'
                    : null,
                decoration:
                    _decoration('Kata sandi', Icons.lock_outline_rounded)
                        .copyWith(
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Tampilkan kata sandi'
                        : 'Sembunyikan kata sandi',
                    onPressed: _loading
                        ? null
                        : () => setState(
                            () => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 21),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('register_submit'),
                  onPressed: _loading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: _emerald,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _emerald.withValues(alpha: 0.65),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_loading) ...[
                      const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                        child: Text(_loading ? 'Membuat akun…' : 'Daftar',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15))),
                    if (!_loading) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward_rounded, size: 18)
                    ],
                  ]),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                  child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Sudah punya akun?',
                      style: textTheme.bodySmall?.copyWith(color: _muted)),
                  TextButton(
                    key: const Key('register_login'),
                    onPressed:
                        _loading ? null : () => Navigator.maybePop(context),
                    style: TextButton.styleFrom(foregroundColor: _emerald),
                    child: const Text('Masuk',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 21),
      prefixIconColor: _muted,
      suffixIconColor: _muted,
      filled: true,
      fillColor: const Color(0xFFFAFBF8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      errorMaxLines: 2,
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _emerald, width: 1.5)),
    );
  }
}
