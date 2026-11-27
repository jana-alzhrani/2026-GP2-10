import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';

import 'auth_service.dart';
import 'otp_page.dart';

class BeneficiaryRegistrationPage extends StatefulWidget {
  const BeneficiaryRegistrationPage({super.key});

  @override
  State<BeneficiaryRegistrationPage> createState() =>
      _BeneficiaryRegistrationPageState();
}

class _BeneficiaryRegistrationPageState
    extends State<BeneficiaryRegistrationPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _socialSecurityController =
      TextEditingController();

  String? _firstNameError;
  String? _lastNameError;
  String? _phoneError;
  String? _socialSecurityError;
  String? _fileError;

  PlatformFile? _selectedFile;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _socialSecurityController.dispose();
    super.dispose();
  }

  String? _validatePersonName(String value) {
    final name = value.trim();

    if (name.isEmpty) {
      return 'الرجاء تعبئة الحقل';
    }

    if (name.length < 2 || name.length > 50) {
      return 'يجب أن يكون الاسم بين 2 و50 حرفًا';
    }

    return null;
  }

  String? _validatePhone(String value) {
    final phone = value.trim();

    if (phone.isEmpty) {
      return 'الرجاء تعبئة الحقل';
    }

    if (!PhoneUtils.isValidLocal(phone)) {
      return 'رقم الجوال غير صحيح';
    }

    return null;
  }

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

  bool _validateAllFields() {
    final firstNameError = _validatePersonName(_firstNameController.text);
    final lastNameError = _validatePersonName(_lastNameController.text);
    final phoneError = _validatePhone(_phoneController.text);
    final socialSecurityError = _validateSocialSecurity(
      _socialSecurityController.text,
    );
    final fileError = _selectedFile == null
        ? 'الرجاء إرفاق ملف إثبات الضمان الاجتماعي'
        : null;

    setState(() {
      _firstNameError = firstNameError;
      _lastNameError = lastNameError;
      _phoneError = phoneError;
      _socialSecurityError = socialSecurityError;
      _fileError = fileError;
    });

    return firstNameError == null &&
        lastNameError == null &&
        phoneError == null &&
        socialSecurityError == null &&
        fileError == null;
  }

  bool _looksLikePdf(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
  }

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

      final bytes = file.bytes;

      if (bytes == null || !_looksLikePdf(bytes)) {
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

  Future<void> _submitRegistration() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    if (!_validateAllFields()) return;

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();
    final socialSecurity = _socialSecurityController.text.trim();
    final file = _selectedFile!;

    setState(() {
      _isLoading = true;
    });

    await AuthService.sendCode(
      phone: phone,
      onCodeSent: (verificationId, resendToken) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpPage(
              verificationId: verificationId,
              resendToken: resendToken,
              firstName: firstName,
              lastName: lastName,
              phone: phone,
              isLogin: false,
              role: 'beneficiary',
              socialSecurityNumber: socialSecurity,
              socialSecurityPdfBytes: file.bytes!,
              socialSecurityPdfName: file.name,
            ),
          ),
        );
      },
      onError: (error) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        final message = error is FirebaseAuthException
            ? 'خطأ ${error.code}: ${error.message ?? "تعذر إرسال رمز التحقق"}'
            : 'تعذر إرسال رمز التحقق، يرجى المحاولة مرة أخرى';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      },
    );
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
                        icon: const Icon(
                          Icons.arrow_forward,
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

                _buildField(
                  label: 'الاسم الأول',
                  icon: Icons.person,
                  controller: _firstNameController,
                  errorText: _firstNameError,
                  keyboardType: TextInputType.name,
                  onChanged: (value) {
                    if (_firstNameError != null) {
                      setState(() => _firstNameError = null);
                    }
                  },
                ),

                _buildField(
                  label: 'الاسم الاخير',
                  icon: Icons.person,
                  controller: _lastNameController,
                  errorText: _lastNameError,
                  keyboardType: TextInputType.name,
                  onChanged: (value) {
                    if (_lastNameError != null) {
                      setState(() => _lastNameError = null);
                    }
                  },
                ),

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
