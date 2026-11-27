import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'otp_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final phone = TextEditingController();

  String? firstNameError;
  String? lastNameError;
  String? phoneError;

  bool _isSending = false;

  String? _validateName(String value) {
    final name = value.trim();
    if (name.isEmpty) return 'الرجاء تعبئة الحقل';
    if (name.length < 2 || name.length > 50) {
      return 'يجب أن يكون الاسم بين 2 و 50 حرف';
    }
    return null;
  }

  String? _validatePhone(String value) {
    final phoneNumber = value.trim();
    if (phoneNumber.isEmpty) return 'الرجاء تعبئة الحقل';
    if (!PhoneUtils.isValidLocal(phoneNumber)) return 'رقم الجوال غير صحيح';
    return null;
  }

  Future<void> signup() async {
    if (_isSending) return;

    FocusScope.of(context).unfocus();

    final newFirstNameError = _validateName(firstName.text);
    final newLastNameError = _validateName(lastName.text);
    final newPhoneError = _validatePhone(phone.text);

    setState(() {
      firstNameError = newFirstNameError;
      lastNameError = newLastNameError;
      phoneError = newPhoneError;
    });

    if (newFirstNameError != null ||
        newLastNameError != null ||
        newPhoneError != null) {
      return;
    }

    _isSending = true;

    final phoneNumber = phone.text.trim();

    await AuthService.sendCode(
      phone: phoneNumber,
      onCodeSent: (verificationId, resendToken) {
        _isSending = false;
        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpPage(
              verificationId: verificationId,
              resendToken: resendToken,
              firstName: firstName.text.trim(),
              lastName: lastName.text.trim(),
              phone: phoneNumber,
              isLogin: false,
              role: 'donor',
            ),
          ),
        );
      },
      onError: (error) {
        _isSending = false;
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FirebaseAuthException
                  ? (error.message ?? 'فشل إرسال الكود')
                  : 'حدث خطأ أثناء إرسال رمز التحقق',
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
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
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward, color: Colors.white),
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
                setState(() {
                  if (controller == phone) {
                    phoneError = null;
                  } else if (controller == firstName) {
                    firstNameError = null;
                  } else if (controller == lastName) {
                    lastNameError = null;
                  }
                });
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
