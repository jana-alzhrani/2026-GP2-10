import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_design.dart';

class BeneficiaryDeliveryMethodPage extends StatefulWidget {
  final String userId;
  final List<Map<String, dynamic>> cartItems;

  const BeneficiaryDeliveryMethodPage({
    super.key,
    required this.userId,
    required this.cartItems,
  });

  @override
  State<BeneficiaryDeliveryMethodPage> createState() =>
      _BeneficiaryDeliveryMethodPageState();
}

class _BeneficiaryDeliveryMethodPageState
    extends State<BeneficiaryDeliveryMethodPage> {
  String? selectedMethod;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _shortAddressController = TextEditingController();

  String? selectedCity;
  String? selectedDistrict;
  final List<String> cities = const [
    'الرياض',
    'جدة',
    'مكة',
    'الدمام',
    'الخبر',
    'المدينة',
  ];

  final List<String> riyadhDistricts = const [
    'الملقا',
    'النرجس',
    'الياسمين',
    'العارض',
    'القيروان',
    'حطين',
    'الصحافة',
    'النخيل',
    'العقيق',
    'الربيع',
    'النفل',
    'الوادي',
    'الغدير',
    'الندى',
    'بنبان',
    'العليا',
    'السليمانية',
    'الورود',
    'الملك فهد',
    'المروج',
    'المصيف',
    'التعاون',
    'النزهة',
    'المغرزات',
    'الازدهار',
    'الواحة',
    'صلاح الدين',
    'المرسلات',
    'الرحمانية',
    'المربع',
    'الديرة',
    'البطحاء',
    'الملز',
    'الفوطة',
    'الشميسي',
    'الصالحية',
    'الوزارات',
    'الضباط',
    'الفاروق',
    'جرير',
    'الرمال',
    'اليرموك',
    'المونسية',
    'النهضة',
    'إشبيلية',
    'الخليج',
    'الملك فيصل',
    'النظيم',
    'قرطبة',
    'السعادة',
    'الجنادرية',
    'النسيم الغربي',
    'النسيم الشرقي',
    'الشهداء',
    'القادسية',
    'المعيزلة',
    'الروضة',
    'السلام',
    'الفيحاء',
    'القدس',
    'غرناطة',
    'الروابي',
    'الأندلس',
    'المنار',
    'الحمراء',
    'الريان',
    'الجزيرة',
    'الندوة',
    'السلي',
    'المشاعل',
    'الزهور',
    'الربوة',
    'العريجاء',
    'العريجاء الغربية',
    'العريجاء الوسطى',
    'ظهرة البديعة',
    'البديعة',
    'السويدي',
    'السويدي الغربي',
    'سلطانة',
    'شبرا',
    'لبن',
    'نمار',
    'طويق',
    'ديراب',
    'الشفا',
    'بدر',
    'المروة',
    'الفواز',
    'الحزم',
    'العزيزية',
    'الدار البيضاء',
    'المصفاة',
    'المنصورة',
    'غبيراء',
    'منفوحة',
    'منفوحة الجديدة',
    'اليمامة',
  ];

  final double warehouseLat = 24.7554;
  final double warehouseLng = 46.7262;

  final String warehouseName = 'مستودع مدد - واجهة الرياض';

  final String warehouseHours =
      'الأحد - الخميس: 9:00 ص - 5:00 م\n'
      'الجمعة والسبت: مغلق';

  @override
  void dispose() {
    _shortAddressController.dispose();
    super.dispose();
  }

  Future<void> _openCitySelector() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppDesign.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDesign.radiusXL),
        ),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: AppPadding.screen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppDesign.border,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                AppGap.lg,
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'اختيار المدينة',
                    style: AppDesign.subtitleStyle.copyWith(
                      color: AppDesign.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                AppGap.md,
                ...cities.map((city) {
                  final bool isAvailable = city == 'الرياض';

                  return ListTile(
                    enabled: isAvailable,
                    leading: Icon(
                      isAvailable
                          ? Icons.location_city_outlined
                          : Icons.lock_outline,
                      color: isAvailable
                          ? AppDesign.primary
                          : AppDesign.textSecondary,
                    ),
                    title: Row(
                      children: [
                        Text(
                          city,
                          style: AppDesign.bodyStyle.copyWith(
                            color: isAvailable
                                ? AppDesign.textPrimary
                                : AppDesign.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!isAvailable) ...[
                          AppGap.wSM,
                          Text(
                            'قريبًا',
                            style: AppDesign.captionStyle.copyWith(
                              color: AppDesign.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: selectedCity == city
                        ? const Icon(
                            Icons.check_circle,
                            color: AppDesign.primary,
                          )
                        : null,
                    onTap: isAvailable
                        ? () => Navigator.pop(context, city)
                        : null,
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        selectedCity = result;
        selectedDistrict = null;
      });
    }
  }

  Future<void> _openDistrictSearch() async {
    final TextEditingController searchController = TextEditingController();

    List<String> filteredDistricts = List.from(riyadhDistricts);

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppDesign.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDesign.radiusXL),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.78,
                minChildSize: 0.55,
                maxChildSize: 0.95,
                builder: (context, scrollController) {
                  return Padding(
                    padding: EdgeInsets.only(
                      left: AppDesign.screenPadding,
                      right: AppDesign.screenPadding,
                      top: AppDesign.screenPadding,
                      bottom:
                          MediaQuery.of(context).viewInsets.bottom +
                          AppDesign.screenPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: AppDesign.border,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        AppGap.lg,
                        Text(
                          'اختيار الحي',
                          style: AppDesign.subtitleStyle.copyWith(
                            color: AppDesign.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        AppGap.md,
                        TextField(
                          controller: searchController,
                          decoration: const InputDecoration(
                            labelText: 'ابحث باسم الحي',
                            hintText: 'مثال: المل',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (value) {
                            final query = value.trim();

                            setModalState(() {
                              filteredDistricts = query.isEmpty
                                  ? List.from(riyadhDistricts)
                                  : riyadhDistricts
                                        .where(
                                          (district) =>
                                              district.contains(query),
                                        )
                                        .toList();
                            });
                          },
                        ),
                        AppGap.md,
                        Expanded(
                          child: filteredDistricts.isEmpty
                              ? Center(
                                  child: Text(
                                    'لا توجد نتائج مطابقة',
                                    style: AppDesign.bodySecondaryStyle,
                                  ),
                                )
                              : ListView.separated(
                                  controller: scrollController,
                                  itemCount: filteredDistricts.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final district = filteredDistricts[index];

                                    return ListTile(
                                      title: Text(
                                        district,
                                        textAlign: TextAlign.right,
                                        style: AppDesign.bodyStyle.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      trailing: selectedDistrict == district
                                          ? const Icon(
                                              Icons.check_circle,
                                              color: AppDesign.primary,
                                            )
                                          : null,
                                      onTap: () {
                                        Navigator.pop(context, district);
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        selectedDistrict = result;
      });
    }

    searchController.dispose();
  }

  Future<void> _openWarehouseMap() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$warehouseLat,$warehouseLng',
    );

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح خرائط Google')));
    }
  }

  Widget _selectorBox({
    required String title,
    required String placeholder,
    required String? value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDesign.radiusLG),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesign.spaceMD,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: AppDesign.white,
          borderRadius: BorderRadius.circular(AppDesign.radiusLG),
          border: Border.all(color: AppDesign.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppDesign.primary),
            AppGap.wMD,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppDesign.captionStyle.copyWith(
                      color: AppDesign.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  AppGap.xs,
                  Text(
                    value ?? placeholder,
                    style: AppDesign.bodyStyle.copyWith(
                      color: value == null
                          ? AppDesign.textSecondary
                          : AppDesign.textPrimary,
                      fontWeight: value == null
                          ? FontWeight.w400
                          : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppDesign.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _deliverySection() {
    return Form(
      key: _formKey,
      child: Container(
        margin: const EdgeInsets.only(top: AppDesign.spaceMD),
        padding: const EdgeInsets.all(AppDesign.cardPadding),
        decoration: AppDesign.primaryCardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'بيانات التوصيل',
              style: AppDesign.subtitleStyle.copyWith(
                color: AppDesign.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            AppGap.sm,
            Text(
              'يرجى تحديد موقع استلام التبرعات.',
              style: AppDesign.bodySecondaryStyle,
            ),
            AppGap.lg,
            _selectorBox(
              title: 'المدينة',
              placeholder: 'قم باختيار المدينة',
              value: selectedCity,
              icon: Icons.location_city_outlined,
              onTap: _openCitySelector,
            ),
            AppGap.md,
            Opacity(
              opacity: selectedCity == null ? 0.55 : 1.0,
              child: _selectorBox(
                title: 'الحي',
                placeholder: selectedCity == null
                    ? 'قم باختيار المدينة أولاً'
                    : 'قم باختيار الحي',
                value: selectedDistrict,
                icon: Icons.map_outlined,
                onTap: selectedCity == null
                    ? () {
                        AppDesign.showErrorSnackBar(
                          context,
                          'قم باختيار المدينة أولاً',
                        );
                      }
                    : _openDistrictSearch,
              ),
            ),
            AppGap.md,
            TextFormField(
              controller: _shortAddressController,
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
              validator: (value) {
                final text = value?.trim().toUpperCase() ?? '';

                if (text.isEmpty) {
                  return 'يرجى إدخال العنوان الوطني المختصر';
                }

                if (!RegExp(r'^[A-Z]{4}[0-9]{4}$').hasMatch(text)) {
                  return 'العنوان الوطني المختصر يجب أن يكون 4 حروف إنجليزية ثم 4 أرقام';
                }

                return null;
              },
              decoration: const InputDecoration(
                labelText: 'العنوان الوطني المختصر',
                hintText: 'مثال: RGHA7923',
                prefixIcon: Icon(Icons.badge_outlined),
                counterText: '',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// خطوة مرقّمة داخل بطاقة توضيح المسح
  Widget _scanStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppDesign.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          AppGap.wSM,
          Expanded(
            child: Text(
              text,
              style: AppDesign.captionStyle.copyWith(
                color: AppDesign.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بطاقة توضيح: لازم يمسح الباركود لتأكيد الاستلام
  Widget _scanNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesign.spaceMD),
      decoration: BoxDecoration(
        color: AppDesign.secondary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppDesign.radiusMD),
        border: Border.all(color: AppDesign.secondary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppDesign.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              AppGap.wMD,
              Expanded(
                child: Text(
                  'تأكيد الاستلام بالباركود',
                  style: AppDesign.subtitleStyle.copyWith(
                    color: AppDesign.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          _scanStep(1, 'توجّه إلى المستودع خلال ساعات العمل.'),
          _scanStep(
            2,
            'افتح صفحة "طلباتي" واضغط زر "مسح الباركود لتأكيد الاستلام".',
          ),
          _scanStep(3, 'صوّر الباركود  لتأكيد الاستلام.'),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _pickupSection() {
    return Container(
      margin: const EdgeInsets.only(top: AppDesign.spaceMD),
      padding: const EdgeInsets.all(AppDesign.cardPadding),
      decoration: AppDesign.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'موقع الاستلام',
            style: AppDesign.subtitleStyle.copyWith(
              color: AppDesign.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          AppGap.sm,
          Text(
            warehouseName,
            style: AppDesign.bodyStyle.copyWith(fontWeight: FontWeight.w700),
          ),
          AppGap.md,
          Text(
            'ساعات العمل الرسمية',
            style: AppDesign.subtitleStyle.copyWith(
              color: AppDesign.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          AppGap.xs,
          Text(warehouseHours, style: AppDesign.bodySecondaryStyle),
          AppGap.lg,

          // 👇 توضيح مسح الباركود
          _scanNotice(),

          AppGap.lg,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openWarehouseMap,
              icon: const Icon(Icons.map_outlined),
              label: const Text('فتح موقع المستودع في Google Maps'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = selectedMethod == value;

    return InkWell(
      onTap: () {
        setState(() {
          selectedMethod = value;
        });
      },
      borderRadius: BorderRadius.circular(AppDesign.radiusLG),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppDesign.cardPadding),
        decoration: BoxDecoration(
          color: selected
              ? AppDesign.primary.withOpacity(0.08)
              : AppDesign.white,
          borderRadius: BorderRadius.circular(AppDesign.radiusLG),
          border: Border.all(
            color: selected ? AppDesign.primary : AppDesign.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: selectedMethod,
              activeColor: AppDesign.primary,
              onChanged: (newValue) {
                setState(() {
                  selectedMethod = newValue;
                });
              },
            ),
            Icon(icon, color: AppDesign.primary),
            AppGap.wMD,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppDesign.subtitleStyle.copyWith(
                      color: AppDesign.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  AppGap.xs,
                  Text(
                    subtitle,
                    style: AppDesign.captionStyle.copyWith(
                      color: AppDesign.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesign.cardPadding),
      decoration: AppDesign.softCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'طريقة الاستلام',
            style: AppDesign.h1Style.copyWith(
              color: AppDesign.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          AppGap.xs,
          Text(
            'قم باختيار الطريقة المناسبة لاستلام التبرعات.',
            style: AppDesign.bodySecondaryStyle,
          ),
        ],
      ),
    );
  }

  Future<void> _createRequest() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final requestRef = firestore.collection('requests').doc();

      if (widget.cartItems.isEmpty) {
        if (!mounted) return;
        AppDesign.showErrorSnackBar(context, 'لا توجد قطع لإتمام الطلب');
        return;
      }

      await firestore.runTransaction((transaction) async {
        final itemRefs = <DocumentReference<Map<String, dynamic>>>[];
        final cartRefs = <DocumentReference<Map<String, dynamic>>>[];
        final itemIds = <String>[];
        final boxIds = <String>{};

        // 1. Read and validate everything first
        for (final entry in widget.cartItems) {
          final itemId = (entry['itemId'] ?? '').toString();
          final cartDocId = (entry['cartDocId'] ?? '').toString();

          if (itemId.isEmpty || cartDocId.isEmpty) {
            throw Exception('بيانات القطعة غير مكتملة');
          }

          final itemRef = firestore.collection('items').doc(itemId);
          final cartRef = firestore.collection('cart').doc(cartDocId);

          final itemSnap = await transaction.get(itemRef);
          final cartSnap = await transaction.get(cartRef);

          if (!itemSnap.exists) {
            throw Exception('إحدى القطع لم تعد موجودة');
          }
          if (itemSnap.data()?['status'] != 'available') {
            throw Exception(
              'إحدى القطع لم تعد متاحة، يرجى العودة للسلة والمحاولة مرة أخرى',
            );
          }

          if (!cartSnap.exists) {
            throw Exception('إحدى عناصر السلة لم تعد موجودة');
          }
          final cartData = cartSnap.data();
          if (cartData?['status'] != 'in_cart') {
            throw Exception('إحدى القطع لم تعد موجودة في السلة');
          }
          if (cartData?['beneficiaryId'] != widget.userId) {
            throw Exception('هذه القطعة لا تنتمي إلى حسابك');
          }

          itemRefs.add(itemRef);
          cartRefs.add(cartRef);
          itemIds.add(itemId);

          final boxId = (itemSnap.data()?['boxId'] ?? '').toString();
          if (boxId.isNotEmpty) boxIds.add(boxId);
        }

        // 2. Create the request
        transaction.set(requestRef, {
          'requestId': requestRef.id,
          'beneficiaryId': widget.userId,
          'courierId': null,
          'status': 'requested',
          'deliveryMethod': selectedMethod,
          'itemIds': itemIds,
          'boxIds': boxIds.toList(),
          'createdAt': FieldValue.serverTimestamp(),
          'deliveredAt': null,
          'deliveryAddress': selectedMethod == 'delivery'
              ? {
                  'city': selectedCity,
                  'district': selectedDistrict,
                  'shortNationalAddress': _shortAddressController.text
                      .trim()
                      .toUpperCase(),
                }
              : {
                  'warehouseName': warehouseName,
                  'warehouseLat': warehouseLat,
                  'warehouseLng': warehouseLng,
                },
        });

        // 3. Reserve the items and take them out of the cart
        for (var i = 0; i < itemRefs.length; i++) {
          transaction.update(itemRefs[i], {
            'status': 'reserved',
            'requestId': requestRef.id,
          });
          transaction.update(cartRefs[i], {'status': 'requested'});
        }
      });

      debugPrint('REQUEST CREATED: ${requestRef.id}');

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/beneficiaryHome',
        (route) => false,
        arguments: widget.userId,
      );
    } catch (e) {
      debugPrint('Error creating request: $e');
      if (!mounted) return;

      var message = e.toString();
      if (message.startsWith('Exception: ')) {
        message = message.substring('Exception: '.length);
      }
      AppDesign.showErrorSnackBar(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDesign.background,
        appBar: AppBar(
          title: const Text('طريقة الاستلام'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppDesign.background,
                AppDesign.surfaceAlt,
                AppDesign.background,
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: SingleChildScrollView(
            padding: AppPadding.screen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                AppGap.xl,
                _methodCard(
                  value: 'delivery',
                  title: 'التوصيل',
                  subtitle: 'استلام التبرعات عن طريق التوصيل.',
                  icon: Icons.local_shipping_outlined,
                ),
                if (selectedMethod == 'delivery') _deliverySection(),
                AppGap.md,
                _methodCard(
                  value: 'pickup',
                  title: 'الاستلام',
                  subtitle: 'استلام التبرعات من الموقع المحدد.',
                  icon: Icons.location_on_outlined,
                ),
                if (selectedMethod == 'pickup') _pickupSection(),
                AppGap.xl,
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedMethod == null
                        ? null
                        : () async {
                            if (selectedMethod == 'delivery') {
                              if (selectedCity == null) {
                                AppDesign.showErrorSnackBar(
                                  context,
                                  'قم باختيار المدينة أولاً',
                                );
                                return;
                              }

                              if (selectedDistrict == null) {
                                AppDesign.showErrorSnackBar(
                                  context,
                                  'قم باختيار الحي أولاً',
                                );
                                return;
                              }

                              if (!_formKey.currentState!.validate()) {
                                return;
                              }
                            }

                            final confirmed = await AppDesign.showAppDialog(
                              context: context,
                              title: 'تأكيد طلب التبرع',
                              message: selectedMethod == 'pickup'
                                  ? 'هل أنت متأكد من رغبتك في إرسال طلب التبرع؟\n\nعند الاستلام من المستودع ستحتاج إلى مسح باركود الصناديق لتأكيد التسليم.'
                                  : 'هل أنت متأكد من رغبتك في إرسال طلب التبرع؟',
                            );

                            if (!confirmed) return;
                            print('BEFORE CREATE REQUEST');

                            await _createRequest();
                            print('AFTER CREATE REQUEST');
                          },
                    child: const Text('تأكيد طلب التبرع'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
