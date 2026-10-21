import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_design.dart';

class AddDonationPage extends StatefulWidget {
  final String userId;

  const AddDonationPage({super.key, required this.userId});

  @override
  State<AddDonationPage> createState() => _AddDonationPageState();
}

class _AddDonationPageState extends State<AddDonationPage> {
  bool inputsLocked = false;

  String? selectedGender;
  String? donationId;
  String? itemCountError;

  Map<String, dynamic>? selectedAgeGroup;

  final TextEditingController _itemCountController = TextEditingController();

  final String _apiKey = '';

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  int totalItems = 0;
  int totalBoxes = 0;
  int? openedBox;

  Map<int, List<Map<String, dynamic>>> boxes = {};

  Set<int> savedBoxes = {};

  final List<Map<String, dynamic>> ageGroups = [
    {'label': 'رضّع (0-2)', 'min': 0, 'max': 2},
    {'label': 'أطفال صغار (3-5)', 'min': 3, 'max': 5},
    {'label': 'أطفال (6-9)', 'min': 6, 'max': 9},
    {'label': 'أطفال (10-15)', 'min': 10, 'max': 15},
    {'label': 'بالغون', 'min': 16, 'max': 120},
  ];

  final List<String> sizeRanges = ["XS - S", "S - M", "M - L", "L - XL"];

  String? generalSize;

  // ============================================================
  // Controllers حقول وصف القطع
  // ============================================================

  final Map<String, TextEditingController> _descControllers = {};

  TextEditingController _descCtrl(int box, int idx) {
    return _descControllers.putIfAbsent(
      '${box}_$idx',
      () => TextEditingController(text: boxes[box]![idx]['description'] ?? ''),
    );
  }

  // نشيل الـ controller من الخريطة ونتخلص منه بعد انتهاء الفريم
  // (عشان ما نعمل dispose وهو لسا مربوط بـ TextField)
  void _disposeDescController(String key) {
    final ctrl = _descControllers.remove(key);
    if (ctrl == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ctrl.dispose();
    });
  }

  void _clearDescControllers(int box) {
    final keys = _descControllers.keys
        .where((k) => k.startsWith('${box}_'))
        .toList();

    for (final k in keys) {
      _disposeDescController(k);
    }
  }

  @override
  void dispose() {
    _itemCountController.dispose();

    for (final c in _descControllers.values) {
      c.dispose();
    }
    _descControllers.clear();

    super.dispose();
  }

  bool ageNeedsSize() {
    if (selectedAgeGroup == null) return false;

    return selectedAgeGroup!['label'] == 'بالغون';
  }

  bool needsSize(String? type) {
    return ["قميص", "بنطلون", "فستان", "معطف"].contains(type);
  }

  bool isShoe(String? type) => type == "حذاء";

  Map<String, String> typeMap = {
    "shirt": "قميص",
    "pants": "بنطلون",
    "dress": "فستان",
    "coat": "معطف",
    "shoe": "حذاء",
    "bag": "حقيبة",
    "hat": "قبعة",
  };

  // ============================================================
  // عدد القطع
  // ============================================================

  void _updateItemCount(String value) {
    setState(() {
      itemCountError = null;
    });

    if (value.isEmpty) {
      setState(() {
        totalItems = 0;
        totalBoxes = 0;
        boxes = {};
      });
      return;
    }

    final parsed = int.tryParse(value);

    if (parsed == null) {
      setState(() {
        itemCountError = "الرجاء إدخال أرقام فقط";
      });
      return;
    }

    if (parsed > 100) {
      setState(() {
        itemCountError = "الحد الأقصى 100 قطعة";
        totalItems = 0;
        totalBoxes = 0;
        boxes = {};
      });
      return;
    }

    totalItems = parsed;
    totalBoxes = (totalItems / 5).ceil();

    boxes = {};

    int remainingItems = totalItems;

    for (int i = 1; i <= totalBoxes; i++) {
      int itemsInThisBox = remainingItems >= 5 ? 5 : remainingItems;

      boxes[i] = List.generate(
        itemsInThisBox,
        (index) => {
          'image': null,
          'type': null,
          'size': null,
          'description': '',
          'isValid': false,
          'error': null,
        },
      );

      remainingItems -= itemsInThisBox;
    }

    setState(() {});
  }

  // ============================================================
  // اختيار مصدر الصورة
  // ============================================================

  Future<ImageSource?> _showImageSourceBottomSheet() async {
    return await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            decoration: BoxDecoration(
              color: AppDesign.background,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // مؤشر السحب
                  Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppDesign.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  AppGap.md,

                  // العنوان
                  Row(
                    children: [
                      AppGap.wMD,

                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text(
                              "اختار طريقة إضافة صورة القطعة",
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  AppGap.lg,

                  // الكاميرا
                  _buildImageSourceOption(
                    icon: Icons.camera_alt_outlined,
                    title: "التقاط صورة",
                    subtitle: "استخدم كاميرا الجوال لتصوير القطعة",
                    onTap: () {
                      Navigator.pop(context, ImageSource.camera);
                    },
                  ),

                  AppGap.sm,

                  // المعرض
                  _buildImageSourceOption(
                    icon: Icons.photo_library_outlined,
                    title: "اختيار من المعرض",
                    subtitle: "اختار صورة موجودة في جهازك",
                    onTap: () {
                      Navigator.pop(context, ImageSource.gallery);
                    },
                  ),

                  AppGap.md,

                  // إلغاء
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: AppDesign.border),
                      ),
                      child: const Text(
                        "إلغاء",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // تصميم خيار الكاميرا / المعرض
  // ============================================================

  Widget _buildImageSourceOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppDesign.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppDesign.border),
        ),
        child: Row(
          children: [
            // الأيقونة
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppDesign.softGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: AppDesign.primary, size: 27),
            ),

            AppGap.wMD,

            // النص
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(subtitle, style: AppDesign.captionStyle),
                ],
              ),
            ),

            Icon(Icons.arrow_back_ios_new, size: 17, color: AppDesign.primary),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // اختيار صورة القطعة
  // ============================================================

  Future<void> _pickItemImage(int box, int index) async {
    final ImageSource? source = await _showImageSourceBottomSheet();

    if (source == null) return;

    final ImagePicker picker = ImagePicker();

    try {
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 60,
      );

      if (image == null) return;

      final Uint8List bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        boxes[box]![index]['image'] = bytes;
        boxes[box]![index]['error'] = null;
      });

      await _verifyImageWithGemini(box, index, bytes, image.mimeType);
    } catch (e) {
      if (!mounted) return;

      AppDesign.showErrorSnackBar(context, "تعذر اختيار الصورة");
    }
  }

  // ============================================================
  // رفع الصورة إلى Firebase Storage
  // ============================================================

  Future<Map<String, String>> uploadImage(Uint8List bytes, String path) async {
    final ref = FirebaseStorage.instance.ref().child(path);

    await ref.putData(bytes);

    final url = await ref.getDownloadURL();

    return {'url': url, 'path': ref.fullPath};
  }

  // ============================================================
  // السماح بفتح الصندوق
  // ============================================================

  bool canOpenBox() {
    if (selectedGender == null) return false;

    if (selectedAgeGroup == null) return false;

    if (ageNeedsSize() && generalSize == null) {
      return false;
    }

    return true;
  }

  // ============================================================
  // فحص الصورة باستخدام Gemini
  // ============================================================

  Future<void> _verifyImageWithGemini(
    int box,
    int index,
    Uint8List imageBytes,
    String? mimeType,
  ) async {
    if (!mounted) return;

    setState(() {
      boxes[box]![index]['error'] = "جاري الفحص...";
    });

    final String url =
        'https://generativelanguage.googleapis.com/v1/models/'
        'gemini-2.5-flash:generateContent?key=$_apiKey';

    try {
      String base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {
                  "text": """
Check the image.

If it is a valid clothing item or bag, answer in this format:
Yes - [Type]

Types must be one of:
Shirt, Pants, Dress, Coat, Shoe, Bag, Hat

If invalid, answer:
No

Reject if:
- completely black
- blurry
- not clothing or bag
""",
                },
                {
                  "inline_data": {
                    "mime_type": mimeType ?? "image/jpeg",
                    "data": base64Image,
                  },
                },
              ],
            },
          ],
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        String result = data['candidates'][0]['content']['parts'][0]['text'];

        setState(() {
          String cleaned = result.trim().toLowerCase();

          if (cleaned.startsWith("yes")) {
            String? detectedType;

            if (cleaned.contains("-")) {
              String typeEng = cleaned.split("-")[1].trim();

              detectedType = typeMap[typeEng];
            }

            boxes[box]![index]['isValid'] = true;

            boxes[box]![index]['error'] = null;

            if (detectedType != null && boxes[box]![index]['type'] == null) {
              boxes[box]![index]['type'] = detectedType;
            }

            AppDesign.showImageValidSnackBar(context, "الصورة صالحة");
          } else {
            boxes[box]![index]['image'] = null;

            boxes[box]![index]['type'] = null;

            boxes[box]![index]['isValid'] = false;

            boxes[box]![index]['size'] = null;

            boxes[box]![index]['description'] = '';

            boxes[box]![index]['error'] = null;

            _disposeDescController('${box}_$index');

            AppDesign.showImageInvalidSnackBar(context, "الصورة غير صالحة!");
          }
        });
      } else {
        setState(() {
          boxes[box]![index]['error'] = "فشل الفحص: ${response.statusCode}";
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        boxes[box]![index]['error'] = "فشل الفحص: $e";
      });
    }
  }

  // ============================================================
  // إنشاء التبرع
  // ============================================================

  Future<void> createDonationIfNeeded() async {
    if (donationId != null) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final doc = await firestore.collection('donations').add({
      'donorId': user.uid,
      'gender': selectedGender ?? "",
      'ageGroup': selectedAgeGroup != null ? selectedAgeGroup!['label'] : "",
      'generalSize': generalSize ?? "",
      'numberOfItems': totalItems,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    donationId = doc.id;

    print("NEW donationId => $donationId");
  }

  // ============================================================
  // التحقق من الصندوق (الوصف إجباري)
  // ============================================================

  bool validateBoxBeforeSave(int box) {
    final items = boxes[box]!;

    for (var item in items) {
      if (item['image'] == null) {
        return false;
      }

      if (item['type'] == null) {
        return false;
      }

      if (item['isValid'] != true) {
        return false;
      }

      if (item['type'] == "حذاء" && item['size'] == null) {
        return false;
      }

      final desc = (item['description'] ?? '').toString().trim();

      if (desc.isEmpty) {
        return false;
      }
    }

    return true;
  }

  // ============================================================
  // حفظ الصندوق (كل قطعة دوكمنت في كولكشن items)
  // ============================================================

  Future<void> _submitBox(int box) async {
    if (!validateBoxBeforeSave(box)) {
      AppDesign.showErrorSnackBar(context, "يرجى إكمال جميع الحقول");

      return;
    }

    final confirm = await AppDesign.showAppDialog(
      context: context,
      title: "تأكيد الحفظ",
      message: "هل أنت متأكد من حفظ هذا الصندوق؟",
    );

    if (!confirm) return;

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      await createDonationIfNeeded();

      final items = boxes[box]!;

      // 1) رفع الصور أولاً
      final List<Map<String, String>> uploads = [];

      for (int i = 0; i < items.length; i++) {
        final filePath = 'donations/$donationId/boxes/box_$box/item_$i.jpg';

        final Uint8List imageBytes = items[i]['image'];

        uploads.add(await uploadImage(imageBytes, filePath));
      }

      // 2) كتابة الصندوق + القطع دفعة وحدة (يا الكل يتحفظ يا ولا شي)
      final batch = firestore.batch();

      final boxRef = firestore.collection('donation_boxes').doc();

      batch.set(boxRef, {
        'donationId': donationId,
        'donorId': user.uid,
        'boxNumber': box,
        'gender': selectedGender,
        'ageGroup': selectedAgeGroup,
        'generalSize': generalSize,
        'status': 'draft',
        'itemsCount': items.length,
        'timestamp': FieldValue.serverTimestamp(),
      });

      for (int i = 0; i < items.length; i++) {
        final itemRef = firestore.collection('items').doc();

        batch.set(itemRef, {
          'boxId': boxRef.id, // ربط بالصندوق
          'donationId': donationId, // ربط بالتبرع
          'donorId': user.uid,
          'boxNumber': box,
          'itemNumber': i + 1,
          'type': items[i]['type'],
          'size': items[i]['type'] == "حذاء" ? items[i]['size'] : null,
          'description': items[i]['description'].toString().trim(),
          'imageUrl': uploads[i]['url'],
          'imagePath': uploads[i]['path'],
            'status': 'draft',   

          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) return;

      setState(() {
        boxes[box] = List.generate(
          boxes[box]!.length,
          (_) => {
            'image': null,
            'type': null,
            'size': null,
            'description': '',
            'isValid': false,
            'error': null,
          },
        );

        _clearDescControllers(box);

        savedBoxes.add(box);

        openedBox = null;
      });
    } catch (e) {
      if (!mounted) return;

      AppDesign.showErrorSnackBar(context, "فشل الحفظ: $e");
    }
  }

  // ============================================================
  // هل كل الصناديق محفوظة؟
  // ============================================================

  bool allBoxesSaved() {
    return savedBoxes.length == totalBoxes;
  }

  // ============================================================
  // الرجوع
  // ============================================================

  Future<void> _showLogoutDialog() async {
    final confirm = await AppDesign.showAppDialog(
      context: context,
      title: "الرجوع",
      message: "هل أنتِ متأكدة من الرجوع؟ لن يتم حفظ التبرع الحالي.",
    );

    if (!confirm) return;

    final user = FirebaseAuth.instance.currentUser;

    if (donationId != null) {
      // حذف القطع
      final itemsSnap = await FirebaseFirestore.instance
          .collection('items')
          .where('donationId', isEqualTo: donationId)
          .get();

      for (var doc in itemsSnap.docs) {
        await doc.reference.delete();
      }

      // حذف الصناديق
      final boxesSnap = await FirebaseFirestore.instance
          .collection('donation_boxes')
          .where('donationId', isEqualTo: donationId)
          .get();

      for (var doc in boxesSnap.docs) {
        await doc.reference.delete();
      }

      // حذف التبرع
      await FirebaseFirestore.instance
          .collection('donations')
          .doc(donationId)
          .delete();
    }

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/donorHome',
      (route) => false,
      arguments: user?.uid ?? '',
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDesign.background,

        appBar: AppBar(
          title: const Text("إضافة تبرع"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _showLogoutDialog,
          ),
        ),

        body: SingleChildScrollView(
          padding: AppPadding.screen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // الجنس
              // ==================================================
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "الجنس",
                  prefixIcon: Icon(Icons.person),
                ),
                items: ["ذكر", "أنثى"]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: inputsLocked
                    ? null
                    : (v) {
                        setState(() {
                          selectedGender = v;
                        });
                      },
                value: selectedGender,
              ),

              AppGap.md,

              // ==================================================
              // العمر
              // ==================================================
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(
                  labelText: "الفئة العمرية",
                  prefixIcon: Icon(Icons.cake),
                ),
                items: ageGroups.map((age) {
                  return DropdownMenuItem(
                    value: age,
                    child: Text(age['label']),
                  );
                }).toList(),
                onChanged: inputsLocked
                    ? null
                    : (v) {
                        setState(() {
                          selectedAgeGroup = v;
                        });
                      },
                value: selectedAgeGroup,
              ),

              // ==================================================
              // المقاس العام
              // ==================================================
              if (ageNeedsSize()) ...[
                AppGap.md,

                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: "المقاس",
                    prefixIcon: Icon(Icons.straighten),
                  ),
                  value: generalSize,
                  items: sizeRanges
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: inputsLocked
                      ? null
                      : (v) {
                          setState(() {
                            generalSize = v;
                          });
                        },
                ),
              ],

              AppGap.md,

              // ==================================================
              // عدد القطع
              // ==================================================
              TextField(
                controller: _itemCountController,
                keyboardType: TextInputType.number,
                enabled: !inputsLocked,
                onChanged: inputsLocked ? null : _updateItemCount,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: "إجمالي عدد القطع",
                  errorText: itemCountError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                ),
              ),

              AppGap.lg,

              // ==================================================
              // الصناديق
              // ==================================================
              if (totalBoxes > 0 && openedBox == null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "اختر صندوق للعمل عليه:",
                      style: AppDesign.subtitleStyle,
                    ),

                    AppGap.sm,

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: totalBoxes,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                          ),
                      itemBuilder: (context, idx) {
                        int boxNum = idx + 1;

                        bool isSaved = savedBoxes.contains(boxNum);

                        return GestureDetector(
                          onTap: () {
                            if (!canOpenBox()) {
                              AppDesign.showErrorSnackBar(
                                context,
                                "يرجى إكمال جميع الحقول",
                              );

                              return;
                            }

                            if (!isSaved) {
                              setState(() {
                                openedBox = boxNum;

                                inputsLocked = true;
                              });
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AppDesign.radiusLG,
                              ),
                              gradient: LinearGradient(
                                colors: isSaved
                                    ? [AppDesign.success, AppDesign.primary]
                                    : [
                                        AppDesign.softGreen.withOpacity(0.2),
                                        AppDesign.softGreen,
                                      ],
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isSaved
                                        ? Icons.check_circle
                                        : Icons.inventory_2,
                                    color: Colors.white,
                                    size: 30,
                                  ),

                                  AppGap.xs,

                                  Text(
                                    "صندوق $boxNum",
                                    style: AppDesign.subtitleStyle.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),

                                  Text(
                                    "${boxes[boxNum]?.length ?? 0} قطع",
                                    style: AppDesign.captionStyle.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),

              // ==================================================
              // داخل الصندوق
              // ==================================================
              if (openedBox != null)
                Column(
                  children: [
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              openedBox = null;
                            });
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text("رجوع"),
                        ),
                      ],
                    ),

                    AppGap.sm,

                    ...boxes[openedBox!]!.asMap().entries.map((entry) {
                      int idx = entry.key;

                      var item = entry.value;

                      return Card(
                        child: Padding(
                          padding: AppPadding.card,
                          child: Column(
                            children: [
                              Text(
                                "القطعة رقم ${idx + 1}",
                                style: AppDesign.bodyStyle,
                              ),

                              AppGap.sm,

                              Row(
                                children: [
                                  // ==================================================
                                  // الصورة
                                  // ==================================================
                                  GestureDetector(
                                    onTap: () =>
                                        _pickItemImage(openedBox!, idx),
                                    child: Container(
                                      height: 90,
                                      width: 90,
                                      decoration: BoxDecoration(
                                        color: AppDesign.surfaceAlt,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppDesign.border,
                                        ),
                                      ),
                                      child: item['image'] == null
                                          ? Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.add_a_photo_outlined,
                                                  color: AppDesign.primary,
                                                  size: 28,
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  "إضافة صورة",
                                                  style: AppDesign.captionStyle,
                                                ),
                                              ],
                                            )
                                          : ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Image.memory(
                                                item['image'],
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                    ),
                                  ),

                                  AppGap.wMD,

                                  // ==================================================
                                  // نوع القطعة
                                  // ==================================================
                                  Expanded(
                                    child: Column(
                                      children: [
                                        DropdownButton<String>(
                                          hint: const Text("نوع القطعة"),
                                          value: item['type'],
                                          isExpanded: true,
                                          items:
                                              [
                                                    "قميص",
                                                    "بنطلون",
                                                    "فستان",
                                                    "معطف",
                                                    "حذاء",
                                                    "حقيبة",
                                                    "قبعة",
                                                  ]
                                                  .map(
                                                    (e) => DropdownMenuItem(
                                                      value: e,
                                                      child: Text(e),
                                                    ),
                                                  )
                                                  .toList(),
                                          onChanged: (v) {
                                            setState(() {
                                              boxes[openedBox!]?[idx]['type'] =
                                                  v;

                                              boxes[openedBox!]?[idx]['size'] =
                                                  null;
                                            });
                                          },
                                        ),

                                        // ==================================================
                                        // مقاس الحذاء
                                        // ==================================================
                                        if (item['type'] == "حذاء")
                                          DropdownButton<String>(
                                            hint: const Text("مقاس الحذاء"),
                                            value: item['size'],
                                            isExpanded: true,
                                            items:
                                                List.generate(
                                                      28,
                                                      (i) =>
                                                          (20 + i).toString(),
                                                    )
                                                    .map(
                                                      (e) => DropdownMenuItem(
                                                        value: e,
                                                        child: Text(e),
                                                      ),
                                                    )
                                                    .toList(),
                                            onChanged: (v) {
                                              setState(() {
                                                boxes[openedBox!]?[idx]['size'] =
                                                    v;
                                              });
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              // ==================================================
                              // وصف القطعة (يظهر بعد تحميل الصورة)
                              // ==================================================
                              if (item['image'] != null) ...[
                                AppGap.sm,

                                TextField(
                                  controller: _descCtrl(openedBox!, idx),
                                  maxLines: 2,
                                  maxLength: 200,
                                  onChanged: (v) {
                                    setState(() {
                                      boxes[openedBox!]![idx]['description'] =
                                          v;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    labelText: "وصف القطعة",
                                    hintText:
                                        "مثال: لون، حالة القطعة، الماركة...",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],

                              if (item['error'] != null)
                                Text(
                                  item['error'],
                                  style: AppDesign.captionStyle.copyWith(
                                    color: AppDesign.error,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),

                    AppGap.lg,

                    // ==================================================
                    // حفظ الصندوق (معطّل لين تكتمل كل البيانات)
                    // ==================================================
                    ElevatedButton(
                      onPressed: validateBoxBeforeSave(openedBox!)
                          ? () async {
                              await _submitBox(openedBox!);
                            }
                          : null,
                      child: const Text("حفظ الصندوق"),
                    ),
                  ],
                ),

              AppGap.lg,

              // ==================================================
              // تم
              // ==================================================
              ElevatedButton(
                onPressed: (totalBoxes > 0 && allBoxesSaved())
                    ? () async {
                        try {
                          final user = FirebaseAuth.instance.currentUser;

                          await FirebaseFirestore.instance
                              .collection('donations')
                              .doc(donationId ?? user!.uid)
                              .update({
                                'donorId': user!.uid,
                                'gender': selectedGender ?? "",
                                'ageGroup': selectedAgeGroup?['label'] ?? "",
                                'generalSize': generalSize ?? "",
                                'numberOfItems': totalItems,
                                'updatedAt': FieldValue.serverTimestamp(),
                                'status': 'draft',
                              });

                          AppDesign.showSuccessSnackBar(
                            context,
                            "تم حفظ التبرع بنجاح",
                          );

                          await Future.delayed(const Duration(seconds: 1));

                          if (!mounted) return;

                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/donorHome',
                            (route) => false,
                            arguments: user.uid,
                          );
                        } catch (e) {
                          AppDesign.showErrorSnackBar(
                            context,
                            "حدث خطأ أثناء الإرسال",
                          );
                        }
                      }
                    : null,
                child: const Text("تم"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
