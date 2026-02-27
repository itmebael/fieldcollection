import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard.dart';
import 'selection_screen.dart';
import 'session_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isHoveringUsername = false;
  bool _isHoveringPassword = false;
  bool _isHoveringButton = false;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;
          final isMobile = screenWidth < 700;
          final formWidth =
              isMobile ? (screenWidth * 0.92).clamp(320.0, 460.0) : 460.0;
          final formPadding = isMobile ? 22.0 : 34.0;
          final titleSize = isMobile ? 26.0 : 30.0;
          final subtitleSize = isMobile ? 13.0 : 14.0;
          final fieldSpacing = isMobile ? 14.0 : 16.0;

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFEAF4FF),
                  Color(0xFFD8ECFF),
                  Color(0xFFC4E4FF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Stack(
                    children: [
                      Positioned(
                        top: -screenHeight * 0.15,
                        left: -screenWidth * 0.22,
                        child: Container(
                          width: screenWidth * 0.7,
                          height: screenWidth * 0.7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                const Color(0xFF66B6FF).withValues(alpha: 0.26),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -screenHeight * 0.18,
                        right: -screenWidth * 0.28,
                        child: Container(
                          width: screenWidth * 0.8,
                          height: screenWidth * 0.8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                const Color(0xFF2D83EA).withValues(alpha: 0.20),
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 20),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                              child: Container(
                                width: formWidth,
                                padding: EdgeInsets.all(formPadding),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(32),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    width: 1.2,
                                  ),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.48),
                                      Colors.white.withValues(alpha: 0.20),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF1D4F86)
                                          .withValues(alpha: 0.24),
                                      blurRadius: 40,
                                      offset: const Offset(0, 20),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Align(
                                      alignment: Alignment.center,
                                      child: SizedBox(
                                        height: 264,
                                        width: 264,
                                        child: Image.asset(
                                          'assets/logologo.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.center,
                                      child: Text(
                                        "Field Collection",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: titleSize,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF123C73),
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.center,
                                      child: Text(
                                        "Secure access for municipal operations",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: subtitleSize,
                                          color: const Color(0xFF2C5688)
                                              .withValues(alpha: 0.9),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: isMobile ? 22 : 26),
                                    MouseRegion(
                                      onEnter: (_) => setState(
                                          () => _isHoveringUsername = true),
                                      onExit: (_) => setState(
                                          () => _isHoveringUsername = false),
                                      child: _buildTextField(
                                        label: "Username",
                                        icon: Icons.person_rounded,
                                        isHovering: _isHoveringUsername,
                                        controller: _usernameController,
                                      ),
                                    ),
                                    SizedBox(height: fieldSpacing),
                                    MouseRegion(
                                      onEnter: (_) => setState(
                                          () => _isHoveringPassword = true),
                                      onExit: (_) => setState(
                                          () => _isHoveringPassword = false),
                                      child: _buildTextField(
                                        label: "Password",
                                        icon: Icons.lock_rounded,
                                        obscure: true,
                                        isHovering: _isHoveringPassword,
                                        controller: _passwordController,
                                      ),
                                    ),
                                    SizedBox(height: isMobile ? 20 : 24),
                                    SizedBox(
                                      width: double.infinity,
                                      height: isMobile ? 54 : 58,
                                      child: MouseRegion(
                                        onEnter: (_) => setState(
                                            () => _isHoveringButton = true),
                                        onExit: (_) => setState(
                                            () => _isHoveringButton = false),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 220),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF2F7DD8)
                                                    .withValues(
                                                        alpha: _isHoveringButton
                                                            ? 0.45
                                                            : 0.30),
                                                blurRadius:
                                                    _isHoveringButton ? 26 : 18,
                                                offset: const Offset(0, 10),
                                              ),
                                            ],
                                          ),
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _isHoveringButton
                                                  ? const Color(0xFF2A6FC4)
                                                  : const Color(0xFF2F7DD8),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                              elevation: 0,
                                            ),
                                            onPressed: _isLoading
                                                ? null
                                                : _handleLogin,
                                            child: _isLoading
                                                ? const SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child:
                                                        CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2.3,
                                                    ),
                                                  )
                                                : const Text(
                                                    "LOGIN",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 16,
                                                      letterSpacing: 1.0,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    bool obscure = false,
    required bool isHovering,
    required TextEditingController controller,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isHovering
            ? Colors.white.withValues(alpha: 0.50)
            : Colors.white.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHovering
              ? const Color(0xFF78B6F6)
              : Colors.white.withValues(alpha: 0.65),
          width: 1.1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            border: InputBorder.none,
            labelText: label,
            labelStyle: const TextStyle(
              color: Color(0xFF2C5688),
              fontWeight: FontWeight.w600,
            ),
            icon: Icon(icon, color: const Color(0xFF1F5DA8)),
          ),
          style: const TextStyle(
            color: Color(0xFF0E2F58),
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      if (username.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter both username and password'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final authResponse =
          await Supabase.instance.client.auth.signInWithPassword(
        email: username,
        password: password,
      );
      final user = authResponse.user;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid email or password'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final profile = await Supabase.instance.client
          .from('user_profiles')
          .select('role, is_active')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No user profile found. Contact admin.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final isActive = (profile['is_active'] ?? true) as bool;
      if (!isActive) {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This account is inactive.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final role = (profile['role'] ?? 'staff').toString().trim().toLowerCase();
      if (role == 'admin') {
        await SessionService.saveAdminSession();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const CategorySelectionScreen(isAdmin: false),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
