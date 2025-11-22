import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_mate/screens/home_screen.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final identifier = TextEditingController();
  final password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;


  String? _errorMessage;

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  void initState() {
    super.initState();

    identifier.addListener(_clearErrorOnEdit);
    password.addListener(_clearErrorOnEdit);
  }

  void _clearErrorOnEdit() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  @override
  void dispose() {
    identifier.dispose();
    password.dispose();
    super.dispose();
  }


  String _classifyErrorMessage(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('password') || m.contains('incorrect password') || m.contains('invalid password') || m.contains('wrong password') || m.contains('credentials')) {
      return 'Wrong password — please try again';
    }
    if (m.contains('no user') || m.contains('not found') || m.contains('user not found') || m.contains('does not exist') || m.contains('no account') || m.contains('user') && m.contains('exist')) {
      return 'User not available — check email';
    }

    return 'Login failed. Please check your credentials';
  }
  Future<void> _submit() async {
    final id = identifier.text.trim();
    final pass = password.text.trim();

    if (id.isEmpty || pass.isEmpty) {
      setState(() => _errorMessage = "Please fill all fields");
      return;
    }

    // optional: basic email format check (you call it "identifier" but you use email)
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(id)) {
      setState(() => _errorMessage = "Enter a valid email");
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final auth = context.read<AuthService>();
      final success = await auth.login(id, pass);

      if (success == true) {
        // debug: confirm tokens in secure storage
        await auth.debugReadStoredKeys(); // check console for storage output

        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        return;
      }

      // login returned false (server rejected or other error)
      setState(() => _errorMessage = "Login failed — wrong credentials or server error");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed — check email/password or server logs')),
      );
    } catch (e) {
      final classified = _classifyErrorMessage(e.toString());
      setState(() => _errorMessage = classified);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  InputDecoration _inputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.white54),
      filled: true,
      fillColor: const Color(0xFF262628),
      contentPadding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 20.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30.0),
        borderSide: BorderSide.none,
      ),
    );
  }


  Widget _errorBanner() {
    if (_errorMessage == null) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.redAccent.shade200,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? '',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _errorMessage = null),
            child: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF151516);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.maybePop(context),
                            ),
                          ),

                          const SizedBox(height: 4),

                          const Padding(
                            padding: EdgeInsets.only(left: 4.0, top: 6.0),
                            child: Text(
                              "Hey,\nWelcome\nBack",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                height: 1.05,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),


                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            child: _errorMessage != null
                                ? _errorBanner()
                                : const SizedBox.shrink(),
                          ),

                          const SizedBox(height: 6),


                          TextField(
                            controller: identifier,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(hint: "Email id", icon: Icons.email_outlined),
                            keyboardType: TextInputType.emailAddress,
                          ),

                          const SizedBox(height: 14),

                          TextField(
                            controller: password,
                            style: const TextStyle(color: Colors.white),
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              hintText: "Password",
                              hintStyle: const TextStyle(color: Colors.white54),
                              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF262628),
                              contentPadding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 20.0),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30.0),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, right: 6.0),
                            child: Row(
                              children: [
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    _showSnack("Forgot password tapped");
                                  },
                                  child: const Text("Forgot password?", style: TextStyle(color: Colors.white70)),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),


                          SizedBox(
                            width: screenWidth,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
                                elevation: 0,
                              ),
                              child: _loading
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                  : const Text("Login", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ),

                          const SizedBox(height: 18),
                          const Spacer(),


                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("Don't have an account? ", style: TextStyle(color: Colors.white70)),
                                GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                                  child: const Text("Sign up", style: TextStyle(color: Colors.white, decoration: TextDecoration.underline, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
