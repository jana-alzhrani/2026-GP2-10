import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'otp_page.dart';
import 'app_design.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  String? emailError;
  String? generalError;

  Future<void> login() async {
    String phoneText = email.text.trim();

    setState(() {
      emailError = null;
      generalError = null;
    });

    bool hasError = false;

    if (phoneText.isEmpty) {
      emailError = "الرجاء تعبئة الحقل";
      hasError = true;
    } else if (phoneText.length != 10 || !phoneText.startsWith('05')) {
      emailError = "رقم الجوال غير صحيح";
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    try {
      var userCheck = await FirebaseFirestore.instance
          .collection('Users')
          .where('phone', isEqualTo: phoneText)
          .get();

      if (userCheck.docs.isEmpty) {
        setState(() {
          emailError = "رقم الجوال غير مسجل";
        });
        return;
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneText.startsWith('0')
            ? "+966${phoneText.substring(1)}"
            : "+966$phoneText",

        verificationCompleted: (_) {},

        verificationFailed: (e) {
          print(e.code);
          print(e.message);

          setState(() {
            generalError = e.message ?? "فشل إرسال الكود";
          });
        },

        codeSent: (verificationId, _) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpPage(
                correctCode: verificationId,
                firstName: '',
                lastName: '',
                phone: phoneText,
                isLogin: true,
              ),
            ),
          );
        },

        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      setState(() {
        generalError = "حدث خطأ، حاول مرة أخرى";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesign.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            //  الهيدر
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
                  left: 10,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/');
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

                    // 📱 رقم الجوال
                    buildField(
                      "رقم الجوال",
                      email,
                      Icons.phone,
                      errorText: emailError,
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
                            Navigator.pushNamed(context, '/roleSelection');
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
