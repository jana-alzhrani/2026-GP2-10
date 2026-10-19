import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';

import 'otp_page.dart';

class BeneficiaryRegistrationPage extends StatefulWidget {
  const BeneficiaryRegistrationPage({super.key});

  @override
  State<BeneficiaryRegistrationPage> createState() =>
      _BeneficiaryRegistrationPageState();
}

class _BeneficiaryRegistrationPageState
    extends State<BeneficiaryRegistrationPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _socialSecurityController =
      TextEditingController();

  String? _nameError;
  String? _phoneError;
  String? _socialSecurityError;
  String? _fileError;

  PlatformFile? _selectedFile;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _socialSecurityController.dispose();
    super.dispose();
  }

  // التحقق من الاسم الكامل
  String? _validateName(String value) {
    final name = value.trim();

    if (name.isEmpty) {
      return 'الرجاء تعبئة الحقل';
    }

    final parts = name.split(RegExp(r'\s+'));

    if (parts.length < 2) {
      return 'يرجى إدخال الاسم الكامل';
    }

    if (name.length > 100) {
      return 'يجب ألا يتجاوز الاسم 100 حرف';
    }

    return null;
  }

  // التحقق من رقم الجوال
  String? _validatePhone(String value) {
    final phone = value.trim();

    if (phone.isEmpty) {
      return 'الرجاء تعبئة الحقل';
    }

    if (!RegExp(r'^05[0-9]{8}$').hasMatch(phone)) {
      return 'رقم الجوال غير صحيح';
    }

    return null;
  }

  // التحقق من رقم الضمان الاجتماعي
  String? _validateSocialSecurity(String value) {
    final number = value.trim();

    if (number.isEmpty) {
      return 'الرجاء تعبئة الحقل';
    }

    if (!RegExp(r'^[0-9]{9}$').hasMatch(number)) {
      return 'رقم الضمان الاجتماعي يجب أن يتكون من 9 أرقام';
    }

    return null;
  }

  // التحقق من تكرار رقم الجوال
  Future<bool> _checkPhoneExists(String value) async {
    final phone = value.trim();

    if (!RegExp(r'^05[0-9]{8}$').hasMatch(phone)) {
      return false;
    }

    final normalizedPhone = '+966${phone.substring(1)}';
    final users = FirebaseFirestore.instance.collection('Users');

    final results = await Future.wait([
      users.where('phone', isEqualTo: phone).get(),
      users.where('phone', isEqualTo: normalizedPhone).get(),
      users.where('phoneNumber', isEqualTo: phone).get(),
      users.where('phoneNumber', isEqualTo: normalizedPhone).get(),
    ]);

    return results.any((result) => result.docs.isNotEmpty);
  }

  // التحقق من تكرار رقم الضمان الاجتماعي
  Future<bool> _checkSocialSecurityExists(String value) async {
    final number = value.trim();

    if (!RegExp(r'^[0-9]{9}$').hasMatch(number)) {
      return false;
    }

    final result = await FirebaseFirestore.instance
        .collection('beneficiaries')
        .where('socialSecurityNumber', isEqualTo: number)
        .limit(1)
        .get();

    return result.docs.isNotEmpty;
  }

  // التحقق من جميع الحقول عند الضغط على زر التسجيل
  bool _validateAllFields() {
    final nameError = _validateName(_nameController.text);
    final phoneError = _validatePhone(_phoneController.text);
    final socialSecurityError = _validateSocialSecurity(
      _socialSecurityController.text,
    );

    final fileError = _selectedFile == null
        ? 'الرجاء إرفاق ملف إثبات الضمان الاجتماعي'
        : null;

    setState(() {
      _nameError = nameError;
      _phoneError = phoneError;
      _socialSecurityError = socialSecurityError;
      _fileError = fileError;
    });

    return nameError == null &&
        phoneError == null &&
        socialSecurityError == null &&
        fileError == null;
  }

  // اختيار ملف PDF
  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;

      if (file.size > 10 * 1024 * 1024) {
        setState(() {
          _fileError = 'حجم الملف يجب ألا يتجاوز 10 ميجابايت';
        });
        return;
      }

      if (file.bytes == null) {
        setState(() {
          _fileError = 'تعذر قراءة الملف، يرجى اختياره مرة أخرى';
        });
        return;
      }

      setState(() {
        _selectedFile = file;
        _fileError = null;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر اختيار الملف'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // إرسال طلب التسجيل
  Future<void> _submitRegistration() async {
    FocusScope.of(context).unfocus();

    // التحقق من الحقول وعرض الأخطاء بعد الضغط فقط
    final fieldsValid = _validateAllFields();

    final phone = _phoneController.text.trim();
    final socialSecurity = _socialSecurityController.text.trim();

    // نتحقق من صحة تنسيق الرقم قبل البحث عن التكرار
    final phoneFormatValid = RegExp(r'^05[0-9]{8}$').hasMatch(phone);

    final socialSecurityFormatValid = RegExp(
      r'^[0-9]{9}$',
    ).hasMatch(socialSecurity);

    setState(() {
      _isLoading = true;
    });

    try {
      bool phoneExists = false;
      bool socialSecurityExists = false;

      // فحص تكرار الجوال حتى لو كانت حقول أخرى فارغة
      if (phoneFormatValid) {
        phoneExists = await _checkPhoneExists(phone);
      }

      // فحص تكرار الضمان حتى لو كانت حقول أخرى فارغة
      if (socialSecurityFormatValid) {
        socialSecurityExists = await _checkSocialSecurityExists(socialSecurity);
      }

      if (!mounted) return;

      // إظهار تنبيهات التكرار مع تنبيهات الحقول الناقصة
      setState(() {
        if (phoneExists) {
          _phoneError = 'رقم الجوال مستخدم مسبقاً';
        }

        if (socialSecurityExists) {
          _socialSecurityError = 'رقم الضمان الاجتماعي مسجل مسبقاً';
        }
      });

      // إذا كان هناك حقل ناقص أو رقم مكرر، نوقف التسجيل
      if (!fieldsValid || phoneExists || socialSecurityExists) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final fullName = _nameController.text.trim();
      final normalizedPhone = '+966${phone.substring(1)}';

      // تقسيم الاسم إلى اسم أول وبقية الاسم
      final nameParts = fullName
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .toList();

      final firstName = nameParts.first;
      final lastName = nameParts.skip(1).join(' ');

      // إرسال رمز التحقق إلى الجوال
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: normalizedPhone,

        verificationCompleted: (PhoneAuthCredential credential) {},

        verificationFailed: (FirebaseAuthException e) {
          debugPrint('OTP ERROR CODE: ${e.code}');
          debugPrint('OTP ERROR MESSAGE: ${e.message}');

          if (mounted) {
            setState(() {
              _isLoading = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'خطأ ${e.code}: ${e.message ?? "تعذر إرسال رمز التحقق"}',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 8),
              ),
            );
          }
        },

        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;

          setState(() {
            _isLoading = false;
          });

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpPage(
                correctCode: verificationId,
                firstName: firstName,
                lastName: lastName,
                phone: phone,
                isLogin: false,
                role: 'beneficiary',
                socialSecurityNumber: socialSecurity,
                socialSecurityPdfBytes: _selectedFile!.bytes!,
                socialSecurityPdfName: _selectedFile!.name,
              ),
            ),
          );
        },

        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'تعذر إرسال رمز التحقق'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      debugPrint('Beneficiary registration error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر إرسال رمز التحقق، يرجى المحاولة مرة أخرى'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // صورة مدد
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
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          textDirection: TextDirection.ltr,
                        ),
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
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                // الاسم الكامل
                _buildField(
                  label: 'الاسم الكامل',
                  icon: Icons.person,
                  controller: _nameController,
                  errorText: _nameError,
                  keyboardType: TextInputType.name,
                  onChanged: (value) {
                    if (_nameError != null) {
                      setState(() => _nameError = null);
                    }
                  },
                ),

                // رقم الجوال
                _buildField(
                  label: 'رقم الجوال',
                  icon: Icons.phone,
                  controller: _phoneController,
                  errorText: _phoneError,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  onChanged: (value) {
                    if (_phoneError != null) {
                      setState(() => _phoneError = null);
                    }
                  },
                ),

                // رقم الضمان الاجتماعي
                _buildField(
                  label: 'رقم الضمان الاجتماعي',
                  icon: Icons.badge,
                  controller: _socialSecurityController,
                  errorText: _socialSecurityError,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  onChanged: (value) {
                    if (_socialSecurityError != null) {
                      setState(() => _socialSecurityError = null);
                    }
                  },
                ),

                // إثبات الضمان الاجتماعي
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إثبات الضمان الاجتماعي',
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _isLoading ? null : _pickPdf,
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          height: 55,
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: _fileError != null
                                  ? Colors.red
                                  : Colors.transparent,
                            ),
                          ),
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.picture_as_pdf,
                                  color: Color(0xFF0F5C63),
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _selectedFile?.name ?? 'أرفق ملف PDF',
                                    textAlign: TextAlign.right,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _selectedFile == null
                                          ? const Color(0xFF9E9E9E)
                                          : const Color(0xFF0F5C63),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_fileError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 8),
                          child: Text(
                            _fileError!,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // زر إرسال طلب التسجيل
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F5C63),
                        disabledBackgroundColor: const Color(0xFF8AA7B0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'إرسال طلب التسجيل',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // تنبيه للمستفيد
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7EFF0),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF0F5C63)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'سيتم إرسال بياناتك إلى الإدارة لمراجعة طلبك والتحقق من المستندات.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF5F6B70),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // تصميم حقول الإدخال
  Widget _buildField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String? errorText,
    required TextInputType keyboardType,
    required ValueChanged<String> onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, textAlign: TextAlign.right),
          const SizedBox(height: 6),
          Directionality(
            textDirection: TextDirection.rtl,
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              textAlign: TextAlign.right,
              onChanged: onChanged,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(icon, color: const Color(0xFF0F5C63)),
                errorText: errorText,
                errorStyle: const TextStyle(color: Colors.red),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(
                    color: errorText != null ? Colors.red : Colors.transparent,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Color(0xFF0F5C63)),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
