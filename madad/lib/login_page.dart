import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'otp_page.dart';
import 'app_design.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phoneController = TextEditingController();
  String? phoneError;
  String? generalError;

  bool _isSending = false;

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (_isSending) return;

    final phoneText = phoneController.text.trim();

    String? newPhoneError;

    if (phoneText.isEmpty) {
      newPhoneError = "الرجاء تعبئة الحقل";
    } else if (!PhoneUtils.isValidLocal(phoneText)) {
      newPhoneError = "رقم الجوال غير صحيح";
    }

    setState(() {
      phoneError = newPhoneError;
      generalError = null;
    });

    if (newPhoneError != null) return;

    _isSending = true;

    await AuthService.sendCode(
      phone: phoneText,
      onCodeSent: (verificationId, resendToken) {
        _isSending = false;
        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpPage(
              verificationId: verificationId,
              resendToken: resendToken,
              firstName: '',
              lastName: '',
              phone: phoneText,
              isLogin: true,
            ),
          ),
        );
      },
      onError: (error) {
        _isSending = false;
        if (!mounted) return;

        setState(() {
          generalError = error is FirebaseAuthException
              ? (error.message ?? "فشل إرسال الكود")
              : "حدث خطأ، حاول مرة أخرى";
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesign.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 280,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/madad_icon.jpeg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 10,
                  child: IconButton(
                    icon: Icon(Icons.arrow_forward, color: Colors.white),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacementNamed(context, '/');
                      }
                    },
                  ),
                ),
              ],
            ),

            SafeArea(
              child: Padding(
                padding: AppPadding.screen,
                child: Column(
                  children: [
                    AppGap.md,

                    Text(
                      "تسجيل الدخول",
                      style: AppDesign.h2Style.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    AppGap.lg,

                    if (generalError != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          generalError!,
                          style: TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),

                    buildField(
                      "رقم الجوال",
                      phoneController,
                      Icons.phone,
                      errorText: phoneError,
                    ),

                    AppGap.xl,

                    Padding(
                      padding: AppPadding.horizontal,
                      child: ElevatedButton(
                        onPressed: login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppDesign.primary,
                          minimumSize: Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(60),
                          ),
                        ),
                        child: Text(
                          "تسجيل الدخول",
                          style: AppDesign.buttonOnPrimaryStyle.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    AppGap.md,

                    Row(
                      textDirection: TextDirection.rtl,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "ليس لديك حساب؟",
                          style: AppDesign.bodySecondaryStyle,
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: () {
                            final from = ModalRoute.of(
                              context,
                            )?.settings.arguments;

                            if (from == 'fromRoleSelection' &&
                                Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              Navigator.pushNamed(
                                context,
                                '/roleSelection',
                                arguments: 'fromLogin',
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppDesign.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            "إنشاء حساب",
                            style: AppDesign.bodyStyle.copyWith(
                              color: AppDesign.primary,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildField(
    String label,
    TextEditingController controller,
    IconData icon, {
    String? errorText,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDesign.spaceLG,
        vertical: AppDesign.spaceSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: AppDesign.bodySecondaryStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Directionality(
            textDirection: TextDirection.rtl,
            child: TextField(
              controller: controller,

              textAlign: TextAlign.right,

              style: TextStyle(
                fontFamily: AppDesign.fontFamily,
                fontWeight: FontWeight.w500,
              ),

              decoration: InputDecoration(
                filled: true,
                fillColor: AppDesign.white,
                prefixIcon: Icon(icon, color: AppDesign.textSecondary),
                errorText: errorText,
                errorStyle: TextStyle(color: Colors.red, fontSize: 12),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.red),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.red, width: 1.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
