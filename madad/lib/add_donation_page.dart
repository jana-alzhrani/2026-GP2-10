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
import 'recommender.dart';

class AddDonationPage extends StatefulWidget {
  final String userId;

  const AddDonationPage({super.key, required this.userId});

  @override
  State<AddDonationPage> createState() => _AddDonationPageState();
}

class _AddDonationPageState extends State<AddDonationPage> {
  bool inputsLocked = false;

  bool _saving = false;

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

  @override
  void dispose() {
    _itemCountController.dispose();

    super.dispose();
  }

  bool ageNeedsSize() {
    if (selectedAgeGroup == null) return false;

    return selectedAgeGroup!['label'] == 'بالغون';
  }

  Map<String, String> typeMap = {
    "shirt": "قميص",
    "t-shirt": "تيشيرت",
    "sweater": "كنزة",
    "pants": "بنطلون",
    "skirt": "تنورة",
    "dress": "فستان",
    "jacket": "جاكيت",
    "coat": "معطف",
    "thobe": "ثوب",
    "shemagh": "شماغ",
    "abaya": "عباية",
    "shoe": "حذاء",
    "bag": "حقيبة",
    "hat": "قبعة",
    "shawl": "شال",
    "glasses": "نظارة",
    "watch": "ساعة",
    "belt": "حزام",
    "gloves": "قفازات",
  };

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

    final parsed = int.tryParse(value) ?? 101;

    if (parsed > 100) {
      setState(() {
        itemCountError = "الحد الأقصى 100 قطعة";
        totalItems = 0;
        totalBoxes = 0;
        boxes = {};
      });
      return;
    }

    if (parsed <= 0) {
      setState(() {
        itemCountError = "أدخل عددًا أكبر من صفر";
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
                  Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppDesign.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  AppGap.md,

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

                  _buildImageSourceOption(
                    icon: Icons.camera_alt_outlined,
                    title: "التقاط صورة",
                    subtitle: "استخدم كاميرا الجوال لتصوير القطعة",
                    onTap: () {
                      Navigator.pop(context, ImageSource.camera);
                    },
                  ),

                  AppGap.sm,

                  _buildImageSourceOption(
                    icon: Icons.photo_library_outlined,
                    title: "اختيار من المعرض",
                    subtitle: "اختار صورة موجودة في جهازك",
                    onTap: () {
                      Navigator.pop(context, ImageSource.gallery);
                    },
                  ),

                  AppGap.md,

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

  Future<void> _pickItemImage(int box, int index) async {
    if (boxes[box]![index]['error'] == "جاري الفحص...") return;

    final ImageSource? source = await _showImageSourceBottomSheet();

    if (source == null) return;

    final ImagePicker picker = ImagePicker();

    try {
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image == null) return;

      final Uint8List bytes = await image.readAsBytes();

      if (!mounted) return;

      final Map<String, dynamic> previous = Map<String, dynamic>.from(
        boxes[box]![index],
      );

      setState(() {
        boxes[box]![index]['image'] = bytes;

        boxes[box]![index]['isValid'] = false;
        boxes[box]![index]['description'] = '';
        boxes[box]![index]['error'] = null;
      });

      final bool ok = await _verifyImageWithGemini(
        box,
        index,
        bytes,
        image.mimeType,
      );

      if (!mounted) return;

      if (!ok) {
        final stillThere = boxes.containsKey(box) && index < boxes[box]!.length;

        if (stillThere) {
          setState(() {
            boxes[box]![index] = previous;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;

      AppDesign.showErrorSnackBar(context, "تعذر اختيار الصورة");
    }
  }

  Future<Map<String, String>> uploadImage(Uint8List bytes, String path) async {
    final ref = FirebaseStorage.instance.ref().child(path);

    await ref.putData(
      bytes,
      SettableMetadata(contentType: _detectMime(bytes, 'image/jpeg')),
    );

    final url = await ref.getDownloadURL();

    return {'url': url, 'path': ref.fullPath};
  }

  bool canOpenBox() {
    if (selectedGender == null) return false;

    if (selectedAgeGroup == null) return false;

    if (ageNeedsSize() && generalSize == null) {
      return false;
    }

    return true;
  }

  Map<String, dynamic>? _parseGeminiJson(String text) {
    var cleaned = text.trim();

    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceFirst(RegExp(r'^```[a-zA-Z]*'), '')
          .replaceFirst(RegExp(r'```$'), '')
          .trim();
    }

    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start == -1 || end <= start) return null;

    try {
      final decoded = jsonDecode(cleaned.substring(start, end + 1));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  String _detectMime(Uint8List bytes, String? fallback) {
    if (bytes.length > 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    if (bytes.length > 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'image/jpeg';
    }
    return fallback ?? 'image/jpeg';
  }

  Future<bool> _verifyImageWithGemini(
    int box,
    int index,
    Uint8List imageBytes,
    String? mimeType,
  ) async {
    if (!mounted) return false;

    setState(() {
      boxes[box]![index]['error'] = "جاري الفحص...";
    });

    final String url =
        'https://generativelanguage.googleapis.com/v1beta/models/'
        'gemini-3.5-flash-lite:generateContent?key=$_apiKey';
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

Type notes (group similar items, do not split): Shirt = button or collared top (shirt, blouse, polo); T-Shirt = t-shirt, tank top or simple jersey top; Sweater = warm top (sweater, hoodie, cardigan, sweatshirt); Pants = any bottoms (pants, jeans, shorts, leggings); Dress = dress, jalabiya, jumpsuit, romper or baby onesie; Jacket = light jacket, blazer or vest; Coat = heavy winter coat; Thobe = Saudi/Gulf men's long robe (also bisht); Shemagh = men's Gulf head cloth (shemagh/ghutra); Abaya = women's long cloak (a tarha/hijab/headscarf also counts as Abaya); Sleepwear = use the closest type (T-Shirt or Pants); Shawl = shawl or neck/winter scarf (not a hijab); Glasses = sunglasses or eyeglasses; Watch = wrist watch; Belt = belt; Gloves = gloves or mittens; Bag = any bag (handbag, backpack, school bag, clutch, tote, crossbody, wallet); Skirt = skirt; Hat = hat or cap; Shoe = any footwear (shoes, sandals, slippers, boots).

If it is NOT a valid item from the type list above, answer only:
{"valid": false}

Reject if:
- the photo is so dark that the item cannot be recognized (black or dark-colored items on a dark background are fine)
- so blurry that the item cannot be recognized
- not one of the types in the list

If it is valid, answer only with JSON (no extra text) in this format:
{
  "valid": true,
  "type": "Shirt | T-Shirt | Sweater | Pants | Skirt | Dress | Jacket | Coat | Thobe | Shemagh | Abaya | Shoe | Bag | Hat | Shawl | Glasses | Watch | Belt | Gloves",
  "shortDescription": "short English product title like an online fashion store, 3-10 words: color + material/pattern + style + item (e.g. 'Light blue cotton long sleeve button shirt')"
}
""",
                },
                {
                  "inline_data": {
                    "mime_type": _detectMime(imageBytes, mimeType),
                    "data": base64Image,
                  },
                },
              ],
            },
          ],
        }),
      );

      if (!mounted) return false;

      if (response.statusCode != 200) {
        AppDesign.showErrorSnackBar(
          context,
          "فشل الفحص: ${response.statusCode}",
        );
        return false;
      }

      final data = jsonDecode(response.body);

      String result = data['candidates'][0]['content']['parts'][0]['text'];

      debugPrint('Gemini response: $result');

      final geminiJson = _parseGeminiJson(result);

      final bool isValid = geminiJson != null
          ? geminiJson['valid'] == true &&
                typeMap.containsKey(
                  (geminiJson['type'] ?? '').toString().trim().toLowerCase(),
                )
          : result.trim().toLowerCase().startsWith("yes");

      if (!isValid) {
        AppDesign.showImageInvalidSnackBar(context, "الصورة غير صالحة!");
        return false;
      }

      String? detectedType;

      if (geminiJson != null) {
        detectedType =
            typeMap[(geminiJson['type'] ?? '').toString().trim().toLowerCase()];
      } else {
        final cleaned = result.trim().toLowerCase();

        if (cleaned.contains("-")) {
          String typeEng = cleaned.split("-")[1].trim();

          detectedType = typeMap[typeEng];
        }
      }

      setState(() {
        boxes[box]![index]['description'] =
            (geminiJson?['shortDescription'] ?? '').toString().trim();

        boxes[box]![index]['isValid'] = true;

        boxes[box]![index]['error'] = null;

        if (detectedType != null) {
          if (boxes[box]![index]['type'] != detectedType) {
            boxes[box]![index]['size'] = null;
          }
          boxes[box]![index]['type'] = detectedType;
        }
      });

      AppDesign.showImageValidSnackBar(context, "الصورة صالحة");

      return true;
    } catch (e) {
      if (!mounted) return false;

      AppDesign.showErrorSnackBar(context, "تعذر فحص الصورة، حاول مرة أخرى");

      return false;
    }
  }

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
  }

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
    }

    return true;
  }

  Future<void> _submitBox(int box) async {
    if (_saving) return;

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

    if (_saving) return;
    setState(() => _saving = true);

    final List<String> uploadedPaths = [];
    bool committed = false;

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      await createDonationIfNeeded();

      final items = boxes[box]!;

      final List<Map<String, String>> uploads = [];

      final int stamp = DateTime.now().millisecondsSinceEpoch;

      for (int i = 0; i < items.length; i++) {
        final filePath =
            'donations/$donationId/boxes/box_$box/item_${i}_$stamp.jpg';

        final Uint8List imageBytes = items[i]['image'];

        uploadedPaths.add(filePath);

        uploads.add(await uploadImage(imageBytes, filePath));
      }

      final batch = firestore.batch();

      final boxRef = firestore.collection('donation_boxes').doc();

      batch.set(boxRef, {
        'donationId': donationId,
        'donorId': user.uid,
        'boxNumber': box,
        'gender': selectedGender,
        'ageGroup': selectedAgeGroup!['label'],
        'generalSize': generalSize,
        'status': 'draft',
        'itemsCount': items.length,
      });

      final List<Map<String, dynamic>> toEmbed = [];

      for (int i = 0; i < items.length; i++) {
        final itemRef = firestore.collection('items').doc();
        toEmbed.add({
          'ref': itemRef,
          'imageUrl': uploads[i]['url'],
          'description': (items[i]['description'] ?? '').toString(),
        });

        batch.set(itemRef, {
          'boxId': boxRef.id,
          'donationId': donationId,
          'donorId': user.uid,
          'boxNumber': box,
          'itemNumber': i + 1,
          'type': items[i]['type'],
          'size': items[i]['type'] == "حذاء" ? items[i]['size'] : null,
          'imageUrl': uploads[i]['url'],
          'imagePath': uploads[i]['path'],
          'description': (items[i]['description'] ?? '').toString(),
          'status': 'draft',
        });
      }

      await batch.commit();
      committed = true;

      Recommender.embedInBackground(toEmbed);

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

        savedBoxes.add(box);

        openedBox = null;
      });
    } catch (e) {
      if (!committed) {
        await Future.wait(
          uploadedPaths.map((p) async {
            try {
              await FirebaseStorage.instance.ref().child(p).delete();
            } catch (_) {}
          }),
        );
      }

      if (!mounted) return;

      AppDesign.showErrorSnackBar(context, "فشل الحفظ: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool allBoxesSaved() {
    return savedBoxes.length == totalBoxes;
  }

  Future<void> _confirmDiscard() async {
    if (_saving) return;

    final confirm = await AppDesign.showAppDialog(
      context: context,
      title: "الرجوع",
      message: "هل أنتِ متأكدة من الرجوع؟ لن يتم حفظ التبرع الحالي.",
    );

    if (!confirm || !mounted || _saving) return;

    final user = FirebaseAuth.instance.currentUser;

    if (donationId != null) {
      setState(() => _saving = true);

      try {
        final itemsSnap = await firestore
            .collection('items')
            .where('donationId', isEqualTo: donationId)
            .get();

        final boxesSnap = await firestore
            .collection('donation_boxes')
            .where('donationId', isEqualTo: donationId)
            .get();

        final batch = firestore.batch();
        final List<String> imagePaths = [];

        for (final doc in itemsSnap.docs) {
          final p = (doc.data()['imagePath'] ?? '').toString();
          if (p.isNotEmpty) imagePaths.add(p);

          batch.delete(doc.reference);
        }

        for (final doc in boxesSnap.docs) {
          batch.delete(doc.reference);
        }

        batch.delete(firestore.collection('donations').doc(donationId));

        await batch.commit();

        await Future.wait(
          imagePaths.map((p) async {
            try {
              await FirebaseStorage.instance.ref().child(p).delete();
            } catch (e) {
              debugPrint('Storage cleanup error: $e');
            }
          }),
        );
      } catch (e) {
        if (!mounted) return;

        setState(() => _saving = false);

        AppDesign.showErrorSnackBar(context, "تعذر حذف التبرع، حاول مرة أخرى");
        return;
      }
    }

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/donorHome',
      (route) => false,
      arguments: user?.uid ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmDiscard();
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppDesign.background,

          appBar: AppBar(
            title: const Text("إضافة تبرع"),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _saving ? null : _confirmDiscard,
            ),
          ),

          body: SingleChildScrollView(
            padding: AppPadding.screen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

                if (openedBox != null)
                  Column(
                    children: [
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _saving
                                ? null
                                : () {
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
                                    GestureDetector(
                                      onTap: _saving
                                          ? null
                                          : () =>
                                                _pickItemImage(openedBox!, idx),
                                      child: Container(
                                        height: 90,
                                        width: 90,
                                        decoration: BoxDecoration(
                                          color: AppDesign.surfaceAlt,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                                    style:
                                                        AppDesign.captionStyle,
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
                                                      "تيشيرت",
                                                      "كنزة",
                                                      "بنطلون",
                                                      "تنورة",
                                                      "فستان",
                                                      "جاكيت",
                                                      "معطف",
                                                      "ثوب",
                                                      "شماغ",
                                                      "عباية",
                                                      "حذاء",
                                                      "حقيبة",
                                                      "قبعة",
                                                      "شال",
                                                      "نظارة",
                                                      "ساعة",
                                                      "حزام",
                                                      "قفازات",
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

                      ElevatedButton(
                        onPressed:
                            (!_saving && validateBoxBeforeSave(openedBox!))
                            ? () async {
                                await _submitBox(openedBox!);
                              }
                            : null,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("حفظ الصندوق"),
                      ),
                    ],
                  ),

                AppGap.lg,

                ElevatedButton(
                  onPressed: (totalBoxes > 0 && allBoxesSaved() && !_saving)
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
      ),
    );
  }
}
