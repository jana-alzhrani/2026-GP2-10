import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'otp_page.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final phone = TextEditingController();

  String? firstNameError;
  String? lastNameError;
  String? phoneError;

  Timer? _debouncePhone;

  Future<void> sendPhoneOTP(String phoneNumber) async {
    String formattedPhone;

    if (phoneNumber.startsWith('05')) {
      formattedPhone = '+966${phoneNumber.substring(1)}';
    } else if (phoneNumber.startsWith('5')) {
      formattedPhone = '+966$phoneNumber';
    } else if (phoneNumber.startsWith('+966')) {
      formattedPhone = phoneNumber;
    } else {
      formattedPhone = '+966$phoneNumber';
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: formattedPhone,

      verificationCompleted: (_) {},

      verificationFailed: (e) {
        print('ERROR CODE: ${e.code}');
        print('ERROR MSG: ${e.message}');

        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message ?? 'فشل إرسال الكود')));
      },

      codeSent: (verificationId, _) {
        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpPage(
              correctCode: verificationId,
              firstName: firstName.text.trim(),
              lastName: lastName.text.trim(),
              phone: phone.text.trim(),
              isLogin: false,
            ),
          ),
        );
      },

      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> signup() async {
    setState(() {
      firstNameError = null;
      lastNameError = null;
      phoneError = null;
    });

    bool hasError = false;

    // التحقق من الاسم الأول
    if (firstName.text.trim().isEmpty) {
      firstNameError = 'الرجاء تعبئة الحقل';
      hasError = true;
    } else if (firstName.text.trim().length < 2 ||
        firstName.text.trim().length > 50) {
      firstNameError = 'يجب أن يكون الاسم بين 2 و 50 حرف';
      hasError = true;
    }

    // التحقق من الاسم الأخير
    if (lastName.text.trim().isEmpty) {
      lastNameError = 'الرجاء تعبئة الحقل';
      hasError = true;
    } else if (lastName.text.trim().length < 2 ||
        lastName.text.trim().length > 50) {
      lastNameError = 'يجب أن يكون الاسم بين 2 و 50 حرف';
      hasError = true;
    }

    // التحقق من رقم الجوال
    final phoneNumber = phone.text.trim();

    if (phoneNumber.isEmpty) {
      phoneError = 'الرجاء تعبئة الحقل';
      hasError = true;
    } else if (!RegExp(r'^05\d{8}$').hasMatch(phoneNumber)) {
      phoneError = 'رقم الجوال غير صحيح';
      hasError = true;
    }

    // التحقق من أن رقم الجوال غير مسجل مسبقًا
    if (!hasError) {
      try {
        final phoneCheck = await FirebaseFirestore.instance
            .collection('Users')
            .where('phone', isEqualTo: phoneNumber)
            .get();

        if (phoneCheck.docs.isNotEmpty) {
          phoneError = 'رقم الجوال مستخدم مسبقاً';
          hasError = true;
        }
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر التحقق من رقم الجوال، حاول مرة أخرى'),
          ),
        );
        return;
      }
    }

    if (hasError) {
      setState(() {});
      return;
    }

    try {
      await sendPhoneOTP(phoneNumber);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء إرسال رمز التحقق')),
      );
    }
  }

  @override
  void dispose() {
    _debouncePhone?.cancel();
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 280,
                  width: double.infinity,
                  decoration: const BoxDecoration(
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
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const Text(
              'البيانات الشخصية',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            buildField('الاسم الأول', firstName, Icons.person, firstNameError),

            buildField('الاسم الأخير', lastName, Icons.person, lastNameError),

            buildField('رقم الجوال', phone, Icons.phone, phoneError),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                onPressed: signup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F5C63),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'إنشاء الحساب',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget buildField(
    String label,
    TextEditingController controller,
    IconData icon,
    String? errorText,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label),
          const SizedBox(height: 6),

          Directionality(
            textDirection: TextDirection.rtl,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              keyboardType: controller == phone
                  ? TextInputType.phone
                  : TextInputType.name,

              onChanged: (value) {
                if (controller == phone) {
                  setState(() {
                    phoneError = null;
                  });

                  _debouncePhone?.cancel();

                  final phoneNumber = value.trim();

                  if (!RegExp(r'^05\d{8}$').hasMatch(phoneNumber)) {
                    return;
                  }

                  _debouncePhone = Timer(
                    const Duration(milliseconds: 500),
                    () async {
                      try {
                        final result = await FirebaseFirestore.instance
                            .collection('Users')
                            .where('phone', isEqualTo: phoneNumber)
                            .get();

                        if (!mounted || phone.text.trim() != phoneNumber) {
                          return;
                        }

                        setState(() {
                          phoneError = result.docs.isNotEmpty
                              ? 'رقم الجوال مستخدم مسبقاً'
                              : null;
                        });
                      } catch (e) {
                        debugPrint('Phone duplicate check failed: $e');
                      }
                    },
                  );
                } else {
                  setState(() {
                    if (controller == firstName) {
                      firstNameError = null;
                    } else if (controller == lastName) {
                      lastNameError = null;
                    }
                  });
                }
              },

              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(icon),
                errorText: errorText,
                errorStyle: const TextStyle(color: Colors.red),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
