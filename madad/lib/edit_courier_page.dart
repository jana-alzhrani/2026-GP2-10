import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

  final cityController = TextEditingController(text: 'Riyadh');

  String status = 'active';

  String originalPhone = '';

  bool isLoading = true;
  bool isSaving = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? firstNameError;
  String? lastNameError;
  String? phoneError;
  String? cityError;

  int phoneCheckRequestId = 0;

  @override
  void initState() {
    super.initState();
    loadCourier();
  }

  Future<void> loadCourier() async {
    try {
      final isPending = widget.userId.isEmpty;

      final courierDoc = await _firestore
          .collection('couriers')
          .doc(widget.courierId)
          .get();

      final userDoc = isPending
          ? null
          : await _firestore.collection('Users').doc(widget.userId).get();

      if (!courierDoc.exists || (userDoc != null && !userDoc.exists)) {
        if (!mounted) return;

        AppDesign.showErrorSnackBar(context, 'بيانات السائق غير موجودة');

        Navigator.pop(context);
        return;
      }

      final courierData = courierDoc.data() as Map<String, dynamic>;
      final userData = userDoc?.data() ?? courierData;

      firstNameController.text = userData['firstName']?.toString() ?? '';

      lastNameController.text = userData['lastName']?.toString() ?? '';

      phoneController.text = userData['phone']?.toString() ?? '';

      if (phoneController.text.startsWith('+966')) {
        phoneController.text = '0${phoneController.text.substring(4)}';
      }

      originalPhone = phoneController.text;

      cityController.text = 'Riyadh';

      status = courierData['status']?.toString() ?? 'active';

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
      final phoneCheck = await _firestore
          .collection('Users')
          .where('phone', isEqualTo: phone)
          .get();

      if (!mounted || requestId != phoneCheckRequestId) {
        return;
      }

      final pendingDoc = phone == widget.courierId
          ? null
          : await _firestore.collection('couriers').doc(phone).get();

      if (!mounted || requestId != phoneCheckRequestId) {
        return;
      }

      final phoneUsedByAnotherUser =
          phoneCheck.docs.any((doc) => doc.id != widget.userId) ||
          (pendingDoc?.exists ?? false);

      setState(() {
        phoneError = phoneUsedByAnotherUser ? 'رقم الجوال مسجل مسبقًا' : null;
      });
    } catch (e) {
      debugPrint('Phone duplicate check error: $e');
    }
  }

  Future<void> updateCourier() async {
    FocusScope.of(context).unfocus();

    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final phone = phoneController.text.trim();

    const city = 'Riyadh';

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
    });

    if (hasError) return;

    setState(() {
      isSaving = true;
    });

    try {
      final phoneCheck = await _firestore
          .collection('Users')
          .where('phone', isEqualTo: phone)
          .get();

      final pendingDoc = phone == widget.courierId
          ? null
          : await _firestore.collection('couriers').doc(phone).get();

      final phoneUsedByAnotherUser =
          phoneCheck.docs.any((doc) => doc.id != widget.userId) ||
          (pendingDoc?.exists ?? false);

      if (phoneUsedByAnotherUser) {
        if (!mounted) return;

        setState(() {
          phoneError = 'رقم الجوال مسجل مسبقًا';
          isSaving = false;
        });

        return;
      }

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

      final batch = _firestore.batch();

      final courierRef = _firestore
          .collection('couriers')
          .doc(widget.courierId);

      if (widget.userId.isEmpty) {
        final courierData = {
          'firstName': firstName,
          'lastName': lastName,
          'phone': phone,
          'status': status,
          'city': city,
          'completedDeliveries': 0,
        };

        if (phone == widget.courierId) {
          batch.update(courierRef, courierData);
        } else {
          batch.set(_firestore.collection('couriers').doc(phone), courierData);
          batch.delete(courierRef);
        }
      } else {
        if (phone != originalPhone) {
          try {
            await FirebaseFunctions.instanceFor(region: 'europe-west1')
                .httpsCallable('changeCourierPhone')
                .call({'userId': widget.userId, 'phone': phone});
          } on FirebaseFunctionsException catch (e) {
            debugPrint('Change Courier Phone Error: ${e.code} ${e.message}');

            if (!mounted) return;

            if (e.code == 'already-exists') {
              setState(() {
                phoneError = 'رقم الجوال مسجل مسبقًا';
              });
            } else {
              AppDesign.showErrorSnackBar(
                context,
                'حدث خطأ أثناء تحديث بيانات السائق',
              );
            }

            return;
          }

          originalPhone = phone;
        }

        batch.update(_firestore.collection('Users').doc(widget.userId), {
          'firstName': firstName,
          'lastName': lastName,
        });

        batch.update(courierRef, {'status': status, 'city': city});
      }

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
          title: Stack(
            alignment: Alignment.center,
            children: [
              const Center(child: Text('تعديل بيانات السائق')),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_forward,
                    textDirection: TextDirection.ltr,
                    color: Colors.black,
                    size: 28,
                  ),
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

                    _buildField(
                      controller: cityController,
                      label: 'المدينة',
                      icon: Icons.location_on_outlined,
                      readOnly: true,
                    ),

                    AppGap.md,

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
