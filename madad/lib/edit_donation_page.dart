import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'app_design.dart';
import 'recommender.dart';

class EditDonationPage extends StatefulWidget {
  final String donationId;
  final String? initialGender;
  final String? initialAgeGroupLabel;
  final int initialItemCount;
  final Map<int, List<Map<String, dynamic>>>? initialBoxes;

  const EditDonationPage({
    super.key,
    required this.donationId,
    this.initialGender,
    this.initialAgeGroupLabel,
    required this.initialItemCount,
    this.initialBoxes,
  });

  @override
  State<EditDonationPage> createState() => _EditDonationPageState();
}

class _EditDonationPageState extends State<EditDonationPage> {
  bool inputsLocked = false;
  bool isLoadingBoxes = true;
  bool isSaving = false;
  bool changesSaved = false;

  String? selectedGender;
  String? generalSize;
  String? itemCountError;
  Map<String, dynamic>? selectedAgeGroup;

  final TextEditingController _itemCountController = TextEditingController();

  static const String _apiKey = '';
  static const String _geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-3.5-flash-lite:generateContent';

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  int totalItems = 0;
  int totalBoxes = 0;
  int? openedBox;

  Map<int, List<Map<String, dynamic>>> boxes = {};
  Set<int> savedBoxes = {};

  Set<String> _originalImagePaths = {};

  final List<Map<String, dynamic>> ageGroups = [
    {'label': 'رضّع (0-2)', 'min': 0, 'max': 2},
    {'label': 'أطفال صغار (3-5)', 'min': 3, 'max': 5},
    {'label': 'أطفال (6-9)', 'min': 6, 'max': 9},
    {'label': 'أطفال (10-15)', 'min': 10, 'max': 15},
    {'label': 'بالغون', 'min': 16, 'max': 120},
  ];

  final List<String> sizeRanges = ["XS - S", "S - M", "M - L", "L - XL"];

  final Map<String, String> typeMap = {
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

  late final List<String> _typeOptions = typeMap.values.toList();
  final List<String> _shoeSizes = List.generate(28, (i) => (20 + i).toString());

  Map<String, dynamic>? _findAgeGroupByLabel(String? label) {
    if (label == null || label.trim().isEmpty) return null;

    try {
      return ageGroups.firstWhere(
        (age) => age['label'].toString().trim() == label.trim(),
      );
    } catch (_) {
      return null;
    }
  }

  bool ageNeedsSize() {
    if (selectedAgeGroup == null) return false;
    return selectedAgeGroup!['label'] == 'بالغون';
  }

  bool canOpenBox() {
    if (selectedGender == null) return false;
    if (selectedAgeGroup == null) return false;

    if (ageNeedsSize() && generalSize == null) {
      return false;
    }

    return true;
  }

  bool _hasImage(Map<String, dynamic> item) {
    if (item['image'] != null) return true;
    return (item['imageUrl'] ?? '').toString().isNotEmpty;
  }

  Future<Map<String, String>> uploadImage(Uint8List bytes, String path) async {
    final ref = FirebaseStorage.instance.ref().child(path);

    await ref.putData(bytes);

    final url = await ref.getDownloadURL();

    return {'url': url, 'path': ref.fullPath};
  }

  @override
  void initState() {
    super.initState();

    selectedGender = widget.initialGender;
    selectedAgeGroup = _findAgeGroupByLabel(widget.initialAgeGroupLabel);

    totalItems = widget.initialItemCount;
    _itemCountController.text = widget.initialItemCount == 0
        ? ''
        : widget.initialItemCount.toString();

    if (widget.initialBoxes != null && widget.initialBoxes!.isNotEmpty) {
      final Set<String> paths = {};

      boxes = Map<int, List<Map<String, dynamic>>>.from(
        widget.initialBoxes!.map(
          (key, value) => MapEntry(
            key,
            value.map((item) {
              final m = Map<String, dynamic>.from(item);
              m['description'] = (m['description'] ?? '').toString();
              m['isValid'] =
                  m['isValid'] == true ||
                  (m['imageUrl'] ?? '').toString().isNotEmpty;
              m['needsEmbed'] = false;

              final p = (m['imagePath'] ?? '').toString();
              if (p.isNotEmpty) paths.add(p);

              return m;
            }).toList(),
          ),
        ),
      );

      _originalImagePaths = paths;
      totalBoxes = boxes.length;
      savedBoxes = boxes.keys.toSet();
      isLoadingBoxes = false;

      _loadGeneralSize();
    } else {
      _loadDonationBoxes();
    }
  }

  Future<void> _loadGeneralSize() async {
    try {
      final snap = await firestore
          .collection('donations')
          .doc(widget.donationId)
          .get();

      final gs = (snap.data()?['generalSize'] ?? '').toString();

      if (gs.isNotEmpty && mounted && generalSize == null) {
        setState(() => generalSize = gs);
      }
    } catch (e) {
      debugPrint('General size load error: $e');
    }
  }

  Future<void> _loadDonationBoxes() async {
    try {
      final boxesSnap = await firestore
          .collection('donation_boxes')
          .where('donationId', isEqualTo: widget.donationId)
          .get();

      final itemsSnap = await firestore
          .collection('items')
          .where('donationId', isEqualTo: widget.donationId)
          .get();

      final Map<String, List<Map<String, dynamic>>> itemsByBox = {};

      for (final d in itemsSnap.docs) {
        final data = d.data();
        final boxId = (data['boxId'] ?? '').toString();

        itemsByBox.putIfAbsent(boxId, () => []).add(data);
      }

      final Map<int, List<Map<String, dynamic>>> loadedBoxes = {};
      final Set<String> loadedPaths = {};
      String? loadedGeneralSize;

      for (final doc in boxesSnap.docs) {
        final data = doc.data();

        final int boxNumber = (data['boxNumber'] as num?)?.toInt() ?? 0;

        List<Map<String, dynamic>> rawItems = [...(itemsByBox[doc.id] ?? [])];

        rawItems.sort((a, b) {
          final an = (a['itemNumber'] ?? 0) as num;
          final bn = (b['itemNumber'] ?? 0) as num;
          return an.compareTo(bn);
        });

        if (rawItems.isEmpty && data['items'] is List) {
          rawItems = (data['items'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }

        if (rawItems.isEmpty) continue;

        final gs = (data['generalSize'] ?? '').toString();
        if (gs.isNotEmpty) {
          loadedGeneralSize = gs;
        }

        loadedBoxes[boxNumber] = [];

        for (final map in rawItems) {
          final imageUrl = (map['imageUrl'] ?? '').toString();
          final imagePath = (map['imagePath'] ?? '').toString();

          if (imagePath.isNotEmpty) loadedPaths.add(imagePath);

          loadedBoxes[boxNumber]!.add({
            'image': null,
            'imageUrl': imageUrl.isEmpty ? null : imageUrl,
            'imagePath': imagePath,
            'type': map['type'],
            'size': map['size'],
            'description': (map['description'] ?? '').toString(),
            'isValid': imageUrl.isNotEmpty,
            'needsEmbed': false,
            'error': null,
          });
        }
      }

      if (!mounted) return;

      setState(() {
        if (loadedBoxes.isNotEmpty) {
          boxes = loadedBoxes;

          totalBoxes = loadedBoxes.length;

          totalItems = loadedBoxes.values.fold(
            0,
            (sum, items) => sum + items.length,
          );

          _itemCountController.text = totalItems.toString();

          savedBoxes = loadedBoxes.keys.toSet();
        }

        _originalImagePaths = loadedPaths;

        if (loadedGeneralSize != null) {
          generalSize = loadedGeneralSize;
        }

        isLoadingBoxes = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingBoxes = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل تحميل محتوى التبرع: $e')));
    }
  }

  Map<String, dynamic> _emptyItem() {
    return {
      'image': null,
      'imageUrl': null,
      'imagePath': '',
      'type': null,
      'size': null,
      'description': '',
      'isValid': false,
      'needsEmbed': false,
      'error': null,
    };
  }

  Future<void> _updateItemCount(String value) async {
    setState(() => itemCountError = null);

    final trimmed = value.trim();
    int newCount;

    if (trimmed.isEmpty) {
      newCount = 0;
    } else {
      final parsed = int.tryParse(trimmed);

      if (parsed == null) {
        setState(() => itemCountError = "الرجاء إدخال أرقام فقط");
        return;
      }

      if (parsed > 100) {
        setState(() => itemCountError = "الحد الأقصى 100 قطعة");
        return;
      }

      if (parsed <= 0) {
        setState(() => itemCountError = "أدخل عددًا أكبر من صفر");
        return;
      }

      newCount = parsed;
    }

    if (newCount == totalItems) return;

    if (newCount < totalItems) {
      final ok = await AppDesign.showAppDialog(
        context: context,
        title: 'تقليل عدد القطع',
        message: 'سيتم حذف القطع الزائدة من آخر الصناديق، هل تريد المتابعة؟',
      );

      if (!mounted) return;

      if (!ok) {
        _itemCountController.text = totalItems == 0
            ? ''
            : totalItems.toString();
        return;
      }
    }

    if (newCount == 0) {
      setState(() {
        totalItems = 0;
        totalBoxes = 0;
        boxes = {};
        savedBoxes.clear();
        openedBox = null;
        changesSaved = false;
      });
      return;
    }

    final oldBoxes = boxes.map(
      (key, value) => MapEntry(
        key,
        value.map((item) => Map<String, dynamic>.from(item)).toList(),
      ),
    );

    final newTotalBoxes = (newCount / 5).ceil();

    final Map<int, List<Map<String, dynamic>>> newBoxes = {};
    final Set<int> newSaved = Set<int>.from(savedBoxes);
    int remainingItems = newCount;

    for (int i = 1; i <= newTotalBoxes; i++) {
      final itemsInThisBox = remainingItems >= 5 ? 5 : remainingItems;
      final existing = oldBoxes[i] ?? [];

      if (existing.length >= itemsInThisBox) {
        newBoxes[i] = existing.take(itemsInThisBox).toList();

        if (existing.length > itemsInThisBox) newSaved.remove(i);
      } else {
        final extraItems = List.generate(
          itemsInThisBox - existing.length,
          (_) => _emptyItem(),
        );

        newBoxes[i] = [...existing, ...extraItems];

        newSaved.remove(i);
      }

      remainingItems -= itemsInThisBox;
    }

    newSaved.removeWhere((boxNumber) => boxNumber > newTotalBoxes);

    setState(() {
      totalItems = newCount;
      totalBoxes = newTotalBoxes;
      boxes = newBoxes;
      savedBoxes = newSaved;
      openedBox = null;
      changesSaved = false;
    });
  }

  Future<ImageSource?> _showImageSourceBottomSheet() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
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
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "اختار طريقة إضافة صورة القطعة",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "تقدر تصور صورة جديدة أو تختار صورة من جهازك",
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  AppGap.lg,
                  _buildImageSourceOption(
                    icon: Icons.camera_alt_outlined,
                    title: "التقاط صورة",
                    subtitle: "استخدم كاميرا الجوال لتصوير القطعة",
                    onTap: () =>
                        Navigator.pop(sheetContext, ImageSource.camera),
                  ),
                  AppGap.sm,
                  _buildImageSourceOption(
                    icon: Icons.photo_library_outlined,
                    title: "اختيار من المعرض",
                    subtitle: "اختار صورة موجودة في جهازك",
                    onTap: () =>
                        Navigator.pop(sheetContext, ImageSource.gallery),
                  ),
                  AppGap.md,
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
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
                color: AppDesign.softGreen.withValues(alpha: 0.2),
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
    if (!boxes.containsKey(box) || index < 0 || index >= boxes[box]!.length) {
      if (!mounted) return;
      AppDesign.showErrorSnackBar(context, 'حدث خطأ في تحديد القطعة');
      return;
    }

    if (boxes[box]![index]['error'] == "جاري الفحص...") return;

    final source = await _showImageSourceBottomSheet();
    if (source == null || !mounted) return;

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 60,
      );

      if (image == null) return;

      final Uint8List bytes = await image.readAsBytes();
      if (!mounted) return;

      final Map<String, dynamic> previous = Map<String, dynamic>.from(
        boxes[box]![index],
      );

      setState(() {
        boxes[box]![index]['image'] = bytes;
        boxes[box]![index]['imageUrl'] = null;
        boxes[box]![index]['imagePath'] = '';
        boxes[box]![index]['isValid'] = false;
        boxes[box]![index]['error'] = null;
        boxes[box]![index]['type'] = null;
        boxes[box]![index]['size'] = null;
        boxes[box]![index]['description'] = '';
        savedBoxes.remove(box);
        changesSaved = false;
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
      debugPrint('Image picker error: $e');
    }
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

    if (_apiKey.isEmpty) {
      AppDesign.showErrorSnackBar(context, 'خدمة فحص الصور غير مفعّلة');
      return false;
    }

    setState(() {
      boxes[box]![index]['error'] = "جاري الفحص...";
    });

    try {
      final String base64Image = base64Encode(imageBytes);

      final response = await http
          .post(
            Uri.parse(_geminiUrl),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey,
            },
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
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return false;

      if (response.statusCode != 200) {
        debugPrint('Gemini status: ${response.statusCode}');
        AppDesign.showErrorSnackBar(
          context,
          'تعذر فحص الصورة (${response.statusCode})، حاول مرة أخرى',
        );
        return false;
      }

      final data = jsonDecode(response.body);
      final candidates = data['candidates'];

      if (candidates is! List || candidates.isEmpty) {
        AppDesign.showErrorSnackBar(context, 'تعذر فحص الصورة، حاول مرة أخرى');
        return false;
      }

      final String result =
          (candidates[0]['content']?['parts']?[0]?['text'] ?? '').toString();

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
          detectedType = typeMap[cleaned.split("-")[1].trim()];
        }
      }

      setState(() {
        boxes[box]![index]['description'] =
            (geminiJson?['shortDescription'] ?? '').toString().trim();

        boxes[box]![index]['isValid'] = true;
        boxes[box]![index]['error'] = null;
        boxes[box]![index]['needsEmbed'] = true;

        if (detectedType != null) {
          boxes[box]![index]['type'] = detectedType;
          boxes[box]![index]['size'] = null;
        }
      });

      AppDesign.showImageValidSnackBar(context, "الصورة صالحة");
      return true;
    } catch (e) {
      debugPrint('Gemini error: $e');
      if (!mounted) return false;

      AppDesign.showErrorSnackBar(context, 'تعذر فحص الصورة، حاول مرة أخرى');
      return false;
    }
  }

  bool _isItemComplete(Map<String, dynamic> item) {
    if (!_hasImage(item)) return false;
    if (item['type'] == null) return false;
    if (item['isValid'] != true) return false;
    if (item['type'] == "حذاء" && item['size'] == null) return false;

    return true;
  }

  bool _isAllDataComplete() {
    if (selectedGender == null || selectedAgeGroup == null) return false;

    if (ageNeedsSize() && generalSize == null) return false;

    if (boxes.isEmpty) return false;

    for (final boxItems in boxes.values) {
      for (final item in boxItems) {
        if (!_isItemComplete(item)) return false;
      }
    }

    return true;
  }

  bool _validateOpenedBox(int box) {
    final items = boxes[box] ?? [];

    for (final item in items) {
      if (!_isItemComplete(item)) return false;
    }

    return true;
  }

  Future<void> _markCurrentBoxDone() async {
    if (openedBox == null) return;

    if (!_validateOpenedBox(openedBox!)) {
      AppDesign.showErrorSnackBar(
        context,
        'يرجى إكمال جميع بيانات الصندوق أولاً',
      );
      return;
    }

    final confirm = await AppDesign.showAppDialog(
      context: context,
      title: 'تأكيد الحفظ',
      message: 'هل أنت متأكد من حفظ هذا الصندوق؟',
    );

    if (!confirm || !mounted || openedBox == null) return;

    setState(() {
      savedBoxes.add(openedBox!);
      openedBox = null;
    });
  }

  Future<void> _saveChanges() async {
    if (!_isAllDataComplete()) {
      AppDesign.showErrorSnackBar(
        context,
        'يرجى إكمال جميع الحقول والقطع أولاً',
      );
      return;
    }

    final confirm = await AppDesign.showAppDialog(
      context: context,
      title: 'حفظ التغييرات',
      message: 'هل أنت متأكد من حفظ التغييرات التي أجريتها؟',
    );

    if (!confirm || !mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      AppDesign.showErrorSnackBar(context, 'يجب تسجيل الدخول أولاً');
      return;
    }

    setState(() => isSaving = true);

    final List<String> uploadedNow = [];
    bool committed = false;

    try {
      final int stamp = DateTime.now().millisecondsSinceEpoch;
      final Map<String, Map<String, String>> uploaded = {};
      final Set<String> newPaths = {};
      final List<Future<void>> uploads = [];

      for (final entry in boxes.entries) {
        final int boxNumber = entry.key;
        final items = entry.value;

        for (int i = 0; i < items.length; i++) {
          final e = items[i];
          final String key = '${boxNumber}_$i';
          final String existingUrl = (e['imageUrl'] ?? '').toString();

          if (existingUrl.isNotEmpty) {
            final String p = (e['imagePath'] ?? '').toString();
            uploaded[key] = {'url': existingUrl, 'path': p};
            if (p.isNotEmpty) newPaths.add(p);
          } else {
            final String path =
                'donations/${widget.donationId}/boxes/box_$boxNumber/item_${i}_$stamp.jpg';
            final Uint8List bytes = e['image'] as Uint8List;

            uploadedNow.add(path);

            uploads.add(() async {
              final up = await uploadImage(bytes, path);
              uploaded[key] = up;
              newPaths.add(up['path'] ?? path);
            }());
          }
        }
      }

      await Future.wait(uploads);

      final donationRef = firestore
          .collection('donations')
          .doc(widget.donationId);

      final donationSnap = await donationRef.get();
      final String currentStatus = (donationSnap.data()?['status'] ?? 'draft')
          .toString();

      final oldItemsSnap = await firestore
          .collection('items')
          .where('donationId', isEqualTo: widget.donationId)
          .get();

      final oldBoxesSnap = await firestore
          .collection('donation_boxes')
          .where('donationId', isEqualTo: widget.donationId)
          .get();

      final Map<int, DocumentReference<Map<String, dynamic>>> oldBoxRefs = {};
      for (final d in oldBoxesSnap.docs) {
        final n = (d.data()['boxNumber'] as num?)?.toInt() ?? 0;
        oldBoxRefs.putIfAbsent(n, () => d.reference);
      }

      final Map<String, DocumentReference<Map<String, dynamic>>> oldItemRefs =
          {};
      for (final d in oldItemsSnap.docs) {
        final data = d.data();
        final b = (data['boxNumber'] as num?)?.toInt() ?? 0;
        final n = (data['itemNumber'] as num?)?.toInt() ?? 0;
        oldItemRefs.putIfAbsent('${b}_$n', () => d.reference);
      }

      final batch = firestore.batch();
      final List<Map<String, dynamic>> toEmbed = [];
      final Set<String> keptPaths = {};

      batch.update(donationRef, {
        'gender': selectedGender,
        'ageGroup': selectedAgeGroup!['label'],
        'numberOfItems': totalItems,
        'generalSize': generalSize ?? "",
        'updatedAt': FieldValue.serverTimestamp(),
      });

      for (final entry in boxes.entries) {
        final int boxNumber = entry.key;
        final items = entry.value;

        final existingBoxRef = oldBoxRefs[boxNumber];
        final bool boxIsNew = existingBoxRef == null;
        final boxRef =
            existingBoxRef ?? firestore.collection('donation_boxes').doc();

        keptPaths.add(boxRef.path);

        batch.set(boxRef, {
          'donationId': widget.donationId,
          'donorId': user.uid,
          'boxNumber': boxNumber,
          'gender': selectedGender,
          'ageGroup': {
            'label': selectedAgeGroup!['label'],
            'min': selectedAgeGroup!['min'],
            'max': selectedAgeGroup!['max'],
          },
          'generalSize': generalSize ?? "",
          'itemsCount': items.length,
          if (boxIsNew) ...{
            'status': currentStatus,
            'timestamp': FieldValue.serverTimestamp(),
          } else
            'items': FieldValue.delete(),
        }, SetOptions(merge: true));

        for (int i = 0; i < items.length; i++) {
          final e = items[i];

          final existingItemRef = oldItemRefs['${boxNumber}_${i + 1}'];
          final bool itemIsNew = existingItemRef == null;
          final itemRef =
              existingItemRef ?? firestore.collection('items').doc();

          keptPaths.add(itemRef.path);

          final up = uploaded['${boxNumber}_$i']!;

          if (itemIsNew || e['needsEmbed'] == true) {
            toEmbed.add({
              'ref': itemRef,
              'imageUrl': up['url'],
              'description': (e['description'] ?? '').toString(),
            });
          }

          batch.set(itemRef, {
            'boxId': boxRef.id,
            'donationId': widget.donationId,
            'donorId': user.uid,
            'boxNumber': boxNumber,
            'itemNumber': i + 1,
            'type': e['type'],
            'size': e['type'] == "حذاء" ? e['size'] : null,
            'imageUrl': up['url'],
            'imagePath': up['path'],
            'description': (e['description'] ?? '').toString(),
            if (itemIsNew) ...{
              'status': currentStatus,
              'createdAt': FieldValue.serverTimestamp(),
            } else
              'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      for (final d in oldItemsSnap.docs) {
        if (!keptPaths.contains(d.reference.path)) batch.delete(d.reference);
      }

      for (final d in oldBoxesSnap.docs) {
        if (!keptPaths.contains(d.reference.path)) batch.delete(d.reference);
      }

      await batch.commit();
      committed = true;

      if (toEmbed.isNotEmpty) {
        Recommender.embedInBackground(toEmbed);
      }

      for (final entry in boxes.entries) {
        for (int i = 0; i < entry.value.length; i++) {
          final up = uploaded['${entry.key}_$i']!;
          entry.value[i]['imageUrl'] = up['url'];
          entry.value[i]['imagePath'] = up['path'];
          entry.value[i]['needsEmbed'] = false;
        }
      }

      final unused = _originalImagePaths.difference(newPaths);

      await Future.wait(
        unused.map((p) async {
          try {
            await FirebaseStorage.instance.ref().child(p).delete();
          } catch (e) {
            debugPrint('Storage cleanup error: $e');
          }
        }),
      );

      _originalImagePaths = newPaths;

      if (!mounted) return;

      setState(() {
        isSaving = false;
        changesSaved = true;
      });

      AppDesign.showSuccessSnackBar(context, 'تم حفظ التغييرات بنجاح');
    } catch (e) {
      if (!committed) {
        for (final p in uploadedNow) {
          try {
            await FirebaseStorage.instance.ref().child(p).delete();
          } catch (_) {}
        }
      }

      if (!mounted) return;
      setState(() => isSaving = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل حفظ التغييرات: $e')));
    }
  }

  Future<void> _showBackDialog() async {
    if (isSaving) return;

    if (changesSaved) {
      Navigator.pop(context, true);
      return;
    }

    final confirm = await AppDesign.showAppDialog(
      context: context,
      title: 'الرجوع',
      message: 'لن يتم حفظ التغييرات الحالية، هل تريد الرجوع؟',
    );

    if (confirm && mounted) {
      Navigator.pop(context);
    }
  }

  Widget _buildTopInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesign.spaceLG),
      decoration: BoxDecoration(
        color: AppDesign.background,
        borderRadius: BorderRadius.circular(AppDesign.radiusXL),
        border: Border.all(color: AppDesign.border, width: 1),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppDesign.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_note_rounded,
                color: AppDesign.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: AppDesign.spaceMD),
            Expanded(
              child: Text(
                'يمكنك تعديل بيانات التبرع والصناديق ثم حفظ التغييرات.',
                textAlign: TextAlign.right,
                style: AppDesign.bodySecondaryStyle.copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoxTile(int boxNum) {
    final bool isSaved = savedBoxes.contains(boxNum);

    return GestureDetector(
      onTap: () {
        if (!canOpenBox()) {
          AppDesign.showErrorSnackBar(context, 'يرجى إكمال جميع الحقول');
          return;
        }

        setState(() {
          openedBox = boxNum;
          inputsLocked = true;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDesign.radiusLG),
          gradient: LinearGradient(
            colors: isSaved
                ? [AppDesign.success, AppDesign.primary]
                : [
                    AppDesign.softGreen.withValues(alpha: 0.2),
                    AppDesign.softGreen,
                  ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSaved ? Icons.check_circle : Icons.inventory_2,
                color: Colors.white,
                size: 30,
              ),
              AppGap.xs,
              Text(
                "صندوق $boxNum",
                style: AppDesign.subtitleStyle.copyWith(color: Colors.white),
              ),
              Text(
                "${boxes[boxNum]?.length ?? 0} قطع",
                style: AppDesign.captionStyle.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(int idx, Map<String, dynamic> item) {
    final String? currentType = _typeOptions.contains(item['type'])
        ? item['type'] as String?
        : null;

    final String? currentSize = _shoeSizes.contains(item['size'])
        ? item['size'] as String?
        : null;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusMD),
        side: BorderSide(
          color: item['error'] != null ? AppDesign.error : AppDesign.border,
          width: 1.2,
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: AppDesign.spaceSM),
      child: Padding(
        padding: AppPadding.card,
        child: Column(
          children: [
            Text(
              "القطعة رقم ${idx + 1}",
              style: AppDesign.subtitleStyle.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            AppGap.sm,
            Row(
              children: [
                GestureDetector(
                  onTap: () => _pickItemImage(openedBox!, idx),
                  child: Container(
                    height: 104,
                    width: 104,
                    decoration: BoxDecoration(
                      color: AppDesign.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppDesign.radiusSM),
                      border: Border.all(color: AppDesign.border),
                    ),
                    child: item['image'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppDesign.radiusSM,
                            ),
                            child: Image.memory(
                              item['image'] as Uint8List,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          )
                        : item['imageUrl'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppDesign.radiusSM,
                            ),
                            child: Image.network(
                              item['imageUrl'],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) {
                                return const Icon(Icons.broken_image);
                              },
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.upload_file_rounded,
                                color: AppDesign.primary,
                                size: AppDesign.iconLG,
                              ),
                              AppGap.xs,
                              Text(
                                "انقر لرفع الصورة",
                                textAlign: TextAlign.center,
                                style: AppDesign.captionStyle.copyWith(
                                  color: AppDesign.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                AppGap.wMD,
                Expanded(
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: currentType,
                        decoration: InputDecoration(
                          labelText: "نوع القطعة",
                          filled: true,
                          fillColor: AppDesign.surface,
                        ),
                        items: _typeOptions
                            .map(
                              (e) => DropdownMenuItem<String>(
                                value: e,
                                child: Text(e),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() {
                          boxes[openedBox]![idx]['type'] = v;
                          boxes[openedBox]![idx]['size'] = null;

                          boxes[openedBox]![idx]['description'] = '';
                          boxes[openedBox]![idx]['needsEmbed'] = true;

                          savedBoxes.remove(openedBox);
                          changesSaved = false;
                        }),
                      ),
                      if (item['type'] == "حذاء") ...[
                        AppGap.sm,
                        DropdownButtonFormField<String>(
                          value: currentSize,
                          decoration: InputDecoration(
                            labelText: "مقاس الحذاء",
                            filled: true,
                            fillColor: AppDesign.surface,
                          ),
                          items: _shoeSizes
                              .map(
                                (e) => DropdownMenuItem<String>(
                                  value: e,
                                  child: Text(e),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              boxes[openedBox]![idx]['size'] = v;
                              savedBoxes.remove(openedBox);
                              changesSaved = false;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            if (item['error'] != null) ...[
              AppGap.sm,
              Text(
                item['error'] ?? '',
                style: AppDesign.captionStyle.copyWith(color: AppDesign.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _sharedInputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      errorText: label == "إجمالي عدد القطع" ? itemCountError : null,
      prefixIcon: Icon(icon, color: AppDesign.primary),
      filled: true,
      fillColor: AppDesign.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusLG),
        borderSide: const BorderSide(color: AppDesign.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusLG),
        borderSide: const BorderSide(color: AppDesign.primary, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusLG),
        borderSide: const BorderSide(color: AppDesign.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusLG),
        borderSide: const BorderSide(color: AppDesign.error, width: 1.2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusLG),
        borderSide: const BorderSide(color: AppDesign.border, width: 1),
      ),
    );
  }

  @override
  void dispose() {
    _itemCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showBackDialog();
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              'تعديل التبرع',
              style: AppDesign.h2Style.copyWith(color: AppDesign.textPrimary),
            ),
            centerTitle: true,
            backgroundColor: AppDesign.background,
            foregroundColor: AppDesign.textPrimary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _showBackDialog,
            ),
          ),
          backgroundColor: AppDesign.background,
          body: isLoadingBoxes
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: AppPadding.screen,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopInfoCard(),
                      AppGap.section,

                      DropdownButtonFormField<String>(
                        value: selectedGender,
                        decoration: _sharedInputDecoration(
                          label: "الجنس",
                          icon: Icons.person_outline,
                        ),
                        items: ["ذكر", "أنثى"]
                            .map(
                              (e) => DropdownMenuItem<String>(
                                value: e,
                                child: Text(e),
                              ),
                            )
                            .toList(),
                        onChanged: inputsLocked
                            ? null
                            : (v) => setState(() {
                                selectedGender = v;
                                changesSaved = false;
                              }),
                      ),

                      AppGap.lg,

                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: selectedAgeGroup,
                        decoration: _sharedInputDecoration(
                          label: "الفئة العمرية",
                          icon: Icons.cake_outlined,
                        ),
                        items: ageGroups.map((age) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: age,
                            child: Text(age['label']),
                          );
                        }).toList(),
                        onChanged: inputsLocked
                            ? null
                            : (v) => setState(() {
                                selectedAgeGroup = v;
                                changesSaved = false;

                                if (!ageNeedsSize()) {
                                  generalSize = null;
                                }
                              }),
                      ),

                      if (ageNeedsSize()) ...[
                        AppGap.lg,
                        DropdownButtonFormField<String>(
                          value: sizeRanges.contains(generalSize)
                              ? generalSize
                              : null,
                          decoration: _sharedInputDecoration(
                            label: "المقاس",
                            icon: Icons.straighten,
                          ),
                          items: sizeRanges
                              .map(
                                (e) => DropdownMenuItem<String>(
                                  value: e,
                                  child: Text(e),
                                ),
                              )
                              .toList(),
                          onChanged: inputsLocked
                              ? null
                              : (v) => setState(() {
                                  generalSize = v;
                                  changesSaved = false;
                                }),
                        ),
                      ],

                      AppGap.lg,

                      Focus(
                        onFocusChange: (hasFocus) {
                          if (!hasFocus && !inputsLocked) {
                            _updateItemCount(_itemCountController.text);
                          }
                        },
                        child: TextField(
                          controller: _itemCountController,
                          keyboardType: TextInputType.number,
                          onEditingComplete: () =>
                              FocusScope.of(context).unfocus(),
                          onTapOutside: (_) => FocusScope.of(context).unfocus(),
                          enabled: !inputsLocked,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: _sharedInputDecoration(
                            label: "إجمالي عدد القطع",
                            icon: Icons.format_list_numbered_rounded,
                          ),
                        ),
                      ),

                      AppGap.section,

                      if (totalBoxes > 0 && openedBox == null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "اختر صندوقًا لتعديل محتواه:",
                              style: AppDesign.subtitleStyle.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            AppGap.md,
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: totalBoxes,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: AppDesign.spaceMD,
                                    crossAxisSpacing: AppDesign.spaceMD,
                                    childAspectRatio: 1,
                                  ),
                              itemBuilder: (context, idx) {
                                final boxNum = idx + 1;
                                return _buildBoxTile(boxNum);
                              },
                            ),
                          ],
                        ),

                      if (openedBox != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      "الصندوق رقم $openedBox",
                                      style: AppDesign.h2Style.copyWith(
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 70),
                              ],
                            ),
                            AppGap.sm,
                            ...boxes[openedBox]!.asMap().entries.map(
                              (entry) => _buildItemCard(entry.key, entry.value),
                            ),
                            AppGap.md,
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _validateOpenedBox(openedBox!)
                                    ? _markCurrentBoxDone
                                    : null,
                                child: const Text("حفظ الصندوق"),
                              ),
                            ),
                          ],
                        ),

                      AppGap.section,

                      if (openedBox == null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                savedBoxes.length == totalBoxes &&
                                    totalBoxes > 0 &&
                                    itemCountError == null &&
                                    !isSaving &&
                                    !changesSaved
                                ? _saveChanges
                                : null,
                            child: isSaving
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text("حفظ التغييرات"),
                          ),
                        ),
                        AppGap.md,
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: changesSaved && !isSaving
                                ? () => Navigator.pop(context, true)
                                : null,
                            child: const Text("تم"),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
