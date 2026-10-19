import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_design.dart';

class EditCourierPage extends StatefulWidget {
  final String courierId;
  final String userId;

  const EditCourierPage({
    super.key,
    required this.courierId,
    required this.userId,
  });

  @override
  State<EditCourierPage> createState() => _EditCourierPageState();
}

class _EditCourierPageState extends State<EditCourierPage> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();

  // المدينة ثابتة باللغة الإنجليزية
  final cityController = TextEditingController(text: 'Riyadh');

  String status = 'active';

  bool isLoading = true;
  bool isSaving = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // رسائل الخطأ
  String? firstNameError;
  String? lastNameError;
  String? phoneError;
  String? cityError;

  // لمنع استخدام نتيجة فحص رقم قديم
  int phoneCheckRequestId = 0;

  @override
  void initState() {
    super.initState();
    loadCourier();
  }

  // =========================
  // تحميل بيانات المندوب
  // =========================
  Future<void> loadCourier() async {
    try {
      final userDoc = await _firestore
          .collection('Users')
          .doc(widget.userId)
          .get();

      final courierDoc = await _firestore
          .collection('couriers')
          .doc(widget.courierId)
          .get();

      if (!userDoc.exists || !courierDoc.exists) {
        if (!mounted) return;

        AppDesign.showErrorSnackBar(context, 'بيانات السائق غير موجودة');

        Navigator.pop(context);
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final courierData = courierDoc.data() as Map<String, dynamic>;

      firstNameController.text = userData['firstName']?.toString() ?? '';

      lastNameController.text = userData['lastName']?.toString() ?? '';

      phoneController.text =
          userData['phone']?.toString() ??
          userData['phoneNumber']?.toString() ??
          '';

      // تحويل الرقم الدولي إلى الصيغة المحلية
      if (phoneController.text.startsWith('+966')) {
        phoneController.text = '0${phoneController.text.substring(4)}';
      }

      // المدينة دائمًا Riyadh
      cityController.text = 'Riyadh';

      status = courierData['statues']?.toString() ?? 'active';

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Load Courier Error: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      AppDesign.showErrorSnackBar(context, 'حدث خطأ أثناء تحميل بيانات السائق');
    }
  }

  // =========================
  // التحقق من رقم الجوال
  // =========================
  Future<void> checkPhoneExists(String value) async {
    final phone = value.trim();
    final requestId = ++phoneCheckRequestId;

    if (phone.isEmpty || phone.length < 10) {
      if (!mounted) return;

      setState(() {
        phoneError = null;
      });

      return;
    }

    if (!RegExp(r'^05[0-9]{8}$').hasMatch(phone)) {
      if (!mounted) return;

      setState(() {
        phoneError = 'رقم الجوال غير صحيح';
      });

      return;
    }

    if (!mounted) return;

    setState(() {
      phoneError = null;
    });

    try {
      final normalizedPhone = '+966${phone.substring(1)}';

      final phoneCheck = await _firestore
          .collection('Users')
          .where('phone', isEqualTo: phone)
          .get();

      final normalizedPhoneCheck = await _firestore
          .collection('Users')
          .where('phoneNumber', isEqualTo: normalizedPhone)
          .get();

      if (!mounted || requestId != phoneCheckRequestId) {
        return;
      }

      final phoneUsedByAnotherUser = phoneCheck.docs.any(
        (doc) => doc.id != widget.userId,
      );

      final normalizedPhoneUsedByAnotherUser = normalizedPhoneCheck.docs.any(
        (doc) => doc.id != widget.userId,
      );

      setState(() {
        if (phoneUsedByAnotherUser || normalizedPhoneUsedByAnotherUser) {
          phoneError = 'رقم الجوال مسجل مسبقًا';
        } else {
          phoneError = null;
        }
      });
    } catch (e) {
      debugPrint('Phone duplicate check error: $e');
    }
  }

  // =========================
  // حفظ التعديلات
  // =========================
  Future<void> updateCourier() async {
    FocusScope.of(context).unfocus();

    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final phone = phoneController.text.trim();

    // المدينة ثابتة دائمًا
    const city = 'Riyadh';

    bool hasError = false;

    setState(() {
      firstNameError = null;
      lastNameError = null;
      phoneError = null;
      cityError = null;

      // الاسم الأول
      if (firstName.isEmpty) {
        firstNameError = 'الرجاء تعبئة الحقل';
        hasError = true;
      } else if (firstName.length < 2 || firstName.length > 50) {
        firstNameError = 'يجب أن يكون الاسم بين 2 و50 حرفًا';
        hasError = true;
      }

      // اسم العائلة
      if (lastName.isEmpty) {
        lastNameError = 'الرجاء تعبئة الحقل';
        hasError = true;
      } else if (lastName.length < 2 || lastName.length > 50) {
        lastNameError = 'يجب أن يكون الاسم بين 2 و50 حرفًا';
        hasError = true;
      }

      // رقم الجوال
      if (phone.isEmpty) {
        phoneError = 'الرجاء تعبئة الحقل';
        hasError = true;
      } else if (!RegExp(r'^05[0-9]{8}$').hasMatch(phone)) {
        phoneError = 'رقم الجوال غير صحيح';
        hasError = true;
      }
    });

    if (hasError) return;

    setState(() {
      isSaving = true;
    });

    try {
      final normalizedPhone = '+966${phone.substring(1)}';

      // إعادة فحص رقم الجوال قبل الحفظ
      final phoneCheck = await _firestore
          .collection('Users')
          .where('phone', isEqualTo: phone)
          .get();

      final normalizedPhoneCheck = await _firestore
          .collection('Users')
          .where('phoneNumber', isEqualTo: normalizedPhone)
          .get();

      final phoneUsedByAnotherUser = phoneCheck.docs.any(
        (doc) => doc.id != widget.userId,
      );

      final normalizedPhoneUsedByAnotherUser = normalizedPhoneCheck.docs.any(
        (doc) => doc.id != widget.userId,
      );

      if (phoneUsedByAnotherUser || normalizedPhoneUsedByAnotherUser) {
        if (!mounted) return;

        setState(() {
          phoneError = 'رقم الجوال مسجل مسبقًا';
          isSaving = false;
        });

        return;
      }

      // تأكيد حفظ التعديلات
      if (!mounted) return;

      final confirmed = await AppDesign.showAppDialog(
        context: context,
        title: 'تأكيد التعديل',
        message: 'هل أنت متأكد من حفظ التعديلات؟',
        confirmText: 'تأكيد',
        cancelText: 'إلغاء',
      );

      if (!confirmed) {
        if (mounted) {
          setState(() {
            isSaving = false;
          });
        }
        return;
      }

      if (!mounted) return;

      // تحديث بيانات المستخدم والمندوب
      final batch = _firestore.batch();

      final userRef = _firestore.collection('Users').doc(widget.userId);

      batch.update(userRef, {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'phoneNumber': normalizedPhone,
      });

      final courierRef = _firestore
          .collection('couriers')
          .doc(widget.courierId);

      batch.update(courierRef, {'statues': status, 'city': city});

      await batch.commit();

      if (!mounted) return;

      AppDesign.showSuccessSnackBar(context, 'تم تحديث بيانات السائق بنجاح');

      Navigator.pop(context);
    } catch (e) {
      debugPrint('Update Courier Error: $e');

      if (!mounted) return;

      AppDesign.showErrorSnackBar(context, 'حدث خطأ أثناء تحديث بيانات السائق');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  // =========================
  // تنظيف الحقول
  // =========================
  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    cityController.dispose();

    super.dispose();
  }

  // =========================
  // تصميم الصفحة
  // =========================
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDesign.background,

        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Stack(
            alignment: Alignment.center,
            children: [
              const Center(child: Text('تعديل بيانات السائق')),
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.west, color: Colors.black, size: 28),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),

        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: AppPadding.screen,
                child: Column(
                  children: [
                    // الاسم الأول
                    _buildField(
                      controller: firstNameController,
                      label: 'الاسم الأول',
                      icon: Icons.person_outline,
                      errorText: firstNameError,
                      onChanged: (value) {
                        final name = value.trim();

                        setState(() {
                          if (name.isEmpty) {
                            firstNameError = 'الرجاء تعبئة الحقل';
                          } else if (name.length < 2 || name.length > 50) {
                            firstNameError =
                                'يجب أن يكون الاسم بين 2 و50 حرفًا';
                          } else {
                            firstNameError = null;
                          }
                        });
                      },
                    ),

                    AppGap.md,

                    // اسم العائلة
                    _buildField(
                      controller: lastNameController,
                      label: 'اسم العائلة',
                      icon: Icons.person_outline,
                      errorText: lastNameError,
                      onChanged: (value) {
                        final name = value.trim();

                        setState(() {
                          if (name.isEmpty) {
                            lastNameError = 'الرجاء تعبئة الحقل';
                          } else if (name.length < 2 || name.length > 50) {
                            lastNameError = 'يجب أن يكون الاسم بين 2 و50 حرفًا';
                          } else {
                            lastNameError = null;
                          }
                        });
                      },
                    ),

                    AppGap.md,

                    // رقم الجوال
                    _buildField(
                      controller: phoneController,
                      label: 'رقم الجوال',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 10,
                      errorText: phoneError,
                      onChanged: (value) {
                        checkPhoneExists(value);
                      },
                    ),

                    AppGap.md,

                    // المدينة ثابتة على Riyadh
                    _buildField(
                      controller: cityController,
                      label: 'المدينة',
                      icon: Icons.location_on_outlined,
                      readOnly: true,
                    ),

                    AppGap.md,

                    // الحالة
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(
                        labelText: 'الحالة',
                        prefixIcon: Icon(Icons.circle_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value: 'inactive',
                          child: Text('Inactive'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            status = value;
                          });
                        }
                      },
                    ),

                    AppGap.lg,

                    // زر حفظ التعديلات
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : updateCourier,
                        child: isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                            : const Text('حفظ التعديلات'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // =========================
  // تصميم حقول الإدخال
  // =========================
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? errorText,
    ValueChanged<String>? onChanged,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        errorText: errorText,
        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
        counterText: '',
      ),
    );
  }
}
