import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_design.dart';

class AddCourierPage extends StatefulWidget {
  const AddCourierPage({super.key});

  @override
  State<AddCourierPage> createState() => _AddCourierPageState();
}

class _AddCourierPageState extends State<AddCourierPage> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();

  final cityController = TextEditingController(text: 'Riyadh');

  final String status = 'active';

  bool isLoading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? firstNameError;
  String? lastNameError;
  String? phoneError;
  String? cityError;

  Future<void> addCourier() async {
    FocusScope.of(context).unfocus();

    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final phone = phoneController.text.trim();
    final city = cityController.text.trim();

    bool hasError = false;

    setState(() {
      firstNameError = null;
      lastNameError = null;
      phoneError = null;
      cityError = null;

      if (firstName.isEmpty) {
        firstNameError = 'الرجاء تعبئة الحقل';
        hasError = true;
      } else if (firstName.length < 2 || firstName.length > 50) {
        firstNameError = 'يجب أن يكون الاسم بين 2 و50 حرفًا';
        hasError = true;
      }

      if (lastName.isEmpty) {
        lastNameError = 'الرجاء تعبئة الحقل';
        hasError = true;
      } else if (lastName.length < 2 || lastName.length > 50) {
        lastNameError = 'يجب أن يكون الاسم بين 2 و50 حرفًا';
        hasError = true;
      }

      if (phone.isEmpty) {
        phoneError = 'الرجاء تعبئة الحقل';
        hasError = true;
      } else if (!RegExp(r'^05[0-9]{8}$').hasMatch(phone)) {
        phoneError = 'رقم الجوال غير صحيح';
        hasError = true;
      }

      if (city.isEmpty) {
        cityError = 'الرجاء تعبئة الحقل';
        hasError = true;
      }
    });

    setState(() {
      isLoading = true;
    });

    try {
      final phoneIsValid = RegExp(r'^05[0-9]{8}$').hasMatch(phone);

      if (phoneIsValid) {
        final normalizedPhone = '+966${phone.substring(1)}';

        final checks = await Future.wait([
          _firestore
              .collection('Users')
              .where('phone', isEqualTo: phone)
              .limit(1)
              .get(),
          _firestore
              .collection('Users')
              .where('phone', isEqualTo: normalizedPhone)
              .limit(1)
              .get(),
        ]);

        final pendingCourier = await _firestore
            .collection('couriers')
            .doc(phone)
            .get();

        final phoneExists =
            pendingCourier.exists ||
            checks.any((result) => result.docs.isNotEmpty);

        if (phoneExists) {
          if (!mounted) return;

          setState(() {
            phoneError = 'رقم الجوال مسجل مسبقًا';
          });

          return;
        }
      }

      if (hasError) return;

      if (!mounted) return;

      final confirmed = await AppDesign.showAppDialog(
        context: context,
        title: 'تأكيد إضافة المندوب',
        message: 'هل أنت متأكد من إضافة هذا المندوب؟',
        confirmText: 'تأكيد',
        cancelText: 'إلغاء',
      );

      if (!confirmed) return;

      await _firestore.collection('couriers').doc(phone).set({
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'status': status,
        'city': city,
        'completedDeliveries': 0,
      });

      if (!mounted) return;

      AppDesign.showSuccessSnackBar(context, 'تم إضافة السائق بنجاح');
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Add Courier Error: $e');

      if (!mounted) return;

      AppDesign.showErrorSnackBar(context, 'حدث خطأ أثناء إضافة السائق');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    cityController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDesign.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Center(child: Text('إضافة سائق')),
                Positioned(
                  right: 0,
                  child: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.arrow_forward,
                      textDirection: TextDirection.ltr,
                      color: AppDesign.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: AppPadding.screen,
          child: Column(
            children: [
              _buildField(
                controller: firstNameController,
                label: 'الاسم الأول',
                icon: Icons.person_outline,
                errorText: firstNameError,
              ),

              AppGap.md,

              _buildField(
                controller: lastNameController,
                label: 'اسم العائلة',
                icon: Icons.person_outline,
                errorText: lastNameError,
              ),

              AppGap.md,

              _buildField(
                controller: phoneController,
                label: 'رقم الجوال',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 10,
                errorText: phoneError,
              ),

              AppGap.md,

              _buildField(
                controller: cityController,
                label: 'المدينة',
                icon: Icons.location_on_outlined,
                errorText: cityError,
                readOnly: true,
              ),

              AppGap.lg,

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isLoading ? null : addCourier,
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : const Text('إضافة السائق'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? errorText,
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
