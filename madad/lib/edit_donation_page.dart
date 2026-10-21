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

  // ضع مفتاحك هنا (الأفضل نقل الاستدعاء إلى Cloud Function)
  final String _apiKey = '';
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  int totalItems = 0;
  int totalBoxes = 0;
  int? openedBox;

  Map<int, List<Map<String, dynamic>>> boxes = {};
  Set<int> savedBoxes = {};

  // مسارات الصور المحفوظة حالياً في Storage (عشان نحذف القديمة بعد الحفظ)
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
    "pants": "بنطلون",
    "dress": "فستان",
    "coat": "معطف",
    "shoe": "حذاء",
    "bag": "حقيبة",
    "hat": "قبعة",
  };

  // ============================================================
  // Controllers حقول وصف القطع
  // ============================================================

  final Map<String, TextEditingController> _descControllers = {};

  TextEditingController _descCtrl(int box, int idx) {
    return _descControllers.putIfAbsent(
      '${box}_$idx',
      () => TextEditingController(
        text: (boxes[box]?[idx]['description'] ?? '').toString(),
      ),
    );
  }

  // نتخلص من الـ controller بعد انتهاء الفريم (عشان ما نعمل dispose
  // وهو لسا مربوط بـ TextField)
  void _disposeDescController(String key) {
    final ctrl = _descControllers.remove(key);
    if (ctrl == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ctrl.dispose();
    });
  }

  void _clearAllDescControllers() {
    for (final k in _descControllers.keys.toList()) {
      _disposeDescController(k);
    }
  }

  // ============================================================

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

  // هل القطعة لها صورة (جديدة أو محفوظة)؟
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
      boxes = Map<int, List<Map<String, dynamic>>>.from(
        widget.initialBoxes!.map(
          (key, value) => MapEntry(
            key,
            value.map((item) {
              final m = Map<String, dynamic>.from(item);
              m['description'] = (m['description'] ?? '').toString();
              return m;
            }).toList(),
          ),
        ),
      );

      totalBoxes = boxes.length;
      savedBoxes = boxes.keys.toSet();
      isLoadingBoxes = false;
    } else {
      _loadDonationBoxes();
    }
  }

  Future<Uint8List?> _downloadImage(String? url) async {
    if (url == null || url.isEmpty) return null;

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('Image load error: $e');
    }

    return null;
  }

  // ============================================================
  // تحميل الصناديق + القطع (من كولكشن items)
  // ============================================================

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

      // نجمع القطع حسب الصندوق
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

        final int boxNumber = (data['boxNumber'] ?? 0) as int;

        // القطع من كولكشن items، ولو الصندوق قديم نقرأ من الـ array
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

        // تحميل الصور بالتوازي
        final images = await Future.wait(
          rawItems.map((m) => _downloadImage(m['imageUrl']?.toString())),
        );

        loadedBoxes[boxNumber] = [];

        for (int i = 0; i < rawItems.length; i++) {
          final map = rawItems[i];
          final imageUrl = (map['imageUrl'] ?? '').toString();
          final imagePath = (map['imagePath'] ?? '').toString();

          if (imagePath.isNotEmpty) loadedPaths.add(imagePath);

          loadedBoxes[boxNumber]!.add({
            'image': images[i],
            'imageUrl': imageUrl.isEmpty ? null : imageUrl,
            'imagePath': imagePath,
            'type': map['type'],
            'size': map['size'],
            'description': (map['description'] ?? '').toString(),
            'isValid': imageUrl.isNotEmpty || images[i] != null,
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
      'error': null,
    };
  }

  void _updateItemCount(String value) {
    setState(() {
      itemCountError = null;
      changesSaved = false;
    });

    if (value.isEmpty) {
      _clearAllDescControllers();

      setState(() {
        totalItems = 0;
        totalBoxes = 0;
        boxes = {};
        savedBoxes.clear();
        openedBox = null;
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
      _clearAllDescControllers();

      setState(() {
        itemCountError = "الحد الأقصى 100 قطعة";
        totalItems = 0;
        totalBoxes = 0;
        boxes = {};
        savedBoxes.clear();
        openedBox = null;
      });
      return;
    }

    if (parsed <= 0) return;

    final oldBoxes = boxes.map(
      (key, value) => MapEntry(
        key,
        value.map((item) => Map<String, dynamic>.from(item)).toList(),
      ),
    );

    final newTotalItems = parsed;
    final newTotalBoxes = (newTotalItems / 5).ceil();

    final Map<int, List<Map<String, dynamic>>> newBoxes = {};
    int remainingItems = newTotalItems;

    for (int i = 1; i <= newTotalBoxes; i++) {
      final itemsInThisBox = remainingItems >= 5 ? 5 : remainingItems;
      final existing = oldBoxes[i] ?? [];

      if (existing.length >= itemsInThisBox) {
        newBoxes[i] = existing.take(itemsInThisBox).toList();
      } else {
        final extraItems = List.generate(
          itemsInThisBox - existing.length,
          (_) => _emptyItem(),
        );

        newBoxes[i] = [...existing, ...extraItems];

        // مهم جدًا: الصندوق صار غير محفوظ لأن فيه قطع جديدة
        savedBoxes.remove(i);
      }

      remainingItems -= itemsInThisBox;
    }

    // الـ controllers ترجع تنبني من القيم الموجودة في boxes
    _clearAllDescControllers();

    setState(() {
      totalItems = newTotalItems;
      totalBoxes = newTotalBoxes;
      boxes = newBoxes;
      savedBoxes.removeWhere((boxNumber) => boxNumber > totalBoxes);
      openedBox = null;
    });
  }

  // نفس نافذة اختيار مصدر الصورة الموجودة في صفحة إضافة التبرع.
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
    if (!boxes.containsKey(box) || index < 0 || index >= boxes[box]!.length) {
      if (!mounted) return;
      AppDesign.showErrorSnackBar(context, 'حدث خطأ في تحديد القطعة');
      return;
    }

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

      setState(() {
        // نلغي رابط الصورة القديمة فقط بعد اختيار صورة جديدة بالفعل.
        boxes[box]![index]['image'] = bytes;
        boxes[box]![index]['imageUrl'] = null;
        boxes[box]![index]['imagePath'] = '';
        boxes[box]![index]['isValid'] = false;
        boxes[box]![index]['error'] = null;
        boxes[box]![index]['type'] = null;
        boxes[box]![index]['size'] = null;
        boxes[box]![index]['description'] = '';
        _disposeDescController('${box}_$index');
        savedBoxes.remove(box);
        changesSaved = false;
      });

      await _verifyImageWithGemini(box, index, bytes, image.mimeType);
    } catch (e) {
      if (!mounted) return;
      AppDesign.showErrorSnackBar(context, "تعذر اختيار الصورة");
      debugPrint('Image picker error: $e');
    }
  }

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
        'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=$_apiKey';
    try {
      final String base64Image = base64Encode(imageBytes);

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
        final String result =
            data['candidates'][0]['content']['parts'][0]['text'];

        setState(() {
          final cleaned = result.trim().toLowerCase();

          if (cleaned.startsWith("yes")) {
            String? detectedType;

            if (cleaned.contains("-")) {
              final typeEng = cleaned.split("-")[1].trim();
              detectedType = typeMap[typeEng];
            }

            boxes[box]![index]['isValid'] = true;
            boxes[box]![index]['error'] = null;

            if (detectedType != null) {
              boxes[box]![index]['type'] = detectedType;
              boxes[box]![index]['size'] = null;
            }

            AppDesign.showImageValidSnackBar(context, "الصورة صالحة");
          } else {
            boxes[box]![index]['image'] = null;
            boxes[box]![index]['type'] = null;
            boxes[box]![index]['size'] = null;
            boxes[box]![index]['description'] = '';
            boxes[box]![index]['isValid'] = false;
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
  // التحقق (الوصف إجباري)
  // ============================================================

  bool _isItemComplete(Map<String, dynamic> item) {
    if (!_hasImage(item)) return false;
    if (item['type'] == null) return false;
    if (item['isValid'] != true) return false;
    if (item['type'] == "حذاء" && item['size'] == null) return false;

    final desc = (item['description'] ?? '').toString().trim();
    if (desc.isEmpty) return false;

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

    if (!confirm) return;

    setState(() {
      savedBoxes.add(openedBox!);
      openedBox = null;
    });
  }

  // ============================================================
  // حفظ التغييرات
  // الصناديق في donation_boxes والقطع في items (كل قطعة دوكمنت)
  // ============================================================

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

    if (!confirm) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      AppDesign.showErrorSnackBar(context, 'يجب تسجيل الدخول أولاً');
      return;
    }

    setState(() => isSaving = true);

    try {
      // 1) رفع الصور الجديدة (القديمة نحتفظ برابطها ومسارها)
      final int stamp = DateTime.now().millisecondsSinceEpoch;
      final Map<int, List<Map<String, String>>> uploaded = {};
      final Set<String> newPaths = {};

      for (final entry in boxes.entries) {
        final int boxNumber = entry.key;
        final items = entry.value;

        uploaded[boxNumber] = [];

        for (int i = 0; i < items.length; i++) {
          final e = items[i];

          final String existingUrl = (e['imageUrl'] ?? '').toString();

          if (existingUrl.isNotEmpty) {
            uploaded[boxNumber]!.add({
              'url': existingUrl,
              'path': (e['imagePath'] ?? '').toString(),
            });
          } else {
            final path =
                'donations/${widget.donationId}/boxes/box_$boxNumber/item_${i}_$stamp.jpg';

            final up = await uploadImage(e['image'] as Uint8List, path);

            uploaded[boxNumber]!.add(up);
          }

          final p = uploaded[boxNumber]!.last['path'] ?? '';
          if (p.isNotEmpty) newPaths.add(p);
        }
      }

      // 2) كل شي في batch واحد: حذف القديم + كتابة الجديد
      final batch = firestore.batch();

      final donationRef = firestore
          .collection('donations')
          .doc(widget.donationId);

      batch.update(donationRef, {
        'gender': selectedGender,
        'ageGroup': selectedAgeGroup!['label'],
        'numberOfItems': totalItems,
        'generalSize': generalSize ?? "",
        'status': 'draft',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final oldItems = await firestore
          .collection('items')
          .where('donationId', isEqualTo: widget.donationId)
          .get();

      for (final d in oldItems.docs) {
        batch.delete(d.reference);
      }

      final oldBoxes = await firestore
          .collection('donation_boxes')
          .where('donationId', isEqualTo: widget.donationId)
          .get();

      for (final d in oldBoxes.docs) {
        batch.delete(d.reference);
      }

      for (final entry in boxes.entries) {
        final int boxNumber = entry.key;
        final items = entry.value;

        final boxRef = firestore.collection('donation_boxes').doc();

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
          'status': 'draft',
          'itemsCount': items.length,
          'timestamp': FieldValue.serverTimestamp(),
        });

        for (int i = 0; i < items.length; i++) {
          final e = items[i];
          final itemRef = firestore.collection('items').doc();

          batch.set(itemRef, {
            'boxId': boxRef.id, // ربط بالصندوق
            'donationId': widget.donationId, // ربط بالتبرع
            'donorId': user.uid,
            'boxNumber': boxNumber,
            'itemNumber': i + 1,
            'type': e['type'],
            'size': e['type'] == "حذاء" ? e['size'] : null,
            'description': (e['description'] ?? '').toString().trim(),
            'imageUrl': uploaded[boxNumber]![i]['url'],
            'imagePath': uploaded[boxNumber]![i]['path'],
            'status': 'draft',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();

      // 3) نحدّث الحالة المحلية عشان أي حفظ ثاني يعيد استخدام الصور
      for (final entry in boxes.entries) {
        for (int i = 0; i < entry.value.length; i++) {
          entry.value[i]['imageUrl'] = uploaded[entry.key]![i]['url'];
          entry.value[i]['imagePath'] = uploaded[entry.key]![i]['path'];
        }
      }

      // 4) نحذف من Storage الصور اللي ما عادت مستخدمة
      final unused = _originalImagePaths.difference(newPaths);

      for (final p in unused) {
        try {
          await FirebaseStorage.instance.ref().child(p).delete();
        } catch (e) {
          debugPrint('Storage cleanup error: $e');
        }
      }

      _originalImagePaths = newPaths;

      if (!mounted) return;

      setState(() {
        isSaving = false;
        changesSaved = true;
      });

      AppDesign.showSuccessSnackBar(context, 'تم حفظ التغييرات بنجاح');
    } catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل حفظ التغييرات: $e')));
    }
  }

  void _goToViewDonation() {
    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/viewDonation',
      (route) => false,
      arguments: FirebaseAuth.instance.currentUser?.uid ?? '',
    );
  }

  Future<void> _finishAndGoBack() async {
    AppDesign.showSuccessSnackBar(
      context,
      'تم تعديل التبرع بنجاح ',
      duration: Duration(seconds: 1),
    );

    await Future.delayed(const Duration(milliseconds: 800));
    _goToViewDonation();
  }

  Future<void> _showBackDialog() async {
    if (changesSaved) {
      Navigator.pop(context);
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
                : [AppDesign.softGreen.withOpacity(0.2), AppDesign.softGreen],
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
                        value: item['type'] as String?,
                        decoration: InputDecoration(
                          labelText: "نوع القطعة",
                          filled: true,
                          fillColor: AppDesign.surface,
                        ),
                        items:
                            const [
                                  "قميص",
                                  "بنطلون",
                                  "فستان",
                                  "معطف",
                                  "حذاء",
                                  "حقيبة",
                                  "قبعة",
                                ]
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

                          savedBoxes.remove(openedBox);
                          changesSaved = false;
                        }),
                      ),
                      if (item['type'] == "حذاء") ...[
                        AppGap.sm,
                        DropdownButtonFormField<String>(
                          value: item['size'] as String?,
                          decoration: InputDecoration(
                            labelText: "مقاس الحذاء",
                            filled: true,
                            fillColor: AppDesign.surface,
                          ),
                          items: List.generate(28, (i) => (20 + i).toString())
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

            // ==================================================
            // وصف القطعة (يظهر بعد وجود صورة، وإجباري)
            // ==================================================
            if (_hasImage(item)) ...[
              AppGap.sm,
              TextField(
                controller: _descCtrl(openedBox!, idx),
                maxLines: 2,
                maxLength: 200,
                onChanged: (v) {
                  setState(() {
                    boxes[openedBox]![idx]['description'] = v;
                    savedBoxes.remove(openedBox);
                    changesSaved = false;
                  });
                },
                decoration: InputDecoration(
                  labelText: "وصف القطعة",
                  hintText: "مثال: لون، حالة القطعة، الماركة...",
                  filled: true,
                  fillColor: AppDesign.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],

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

    for (final c in _descControllers.values) {
      c.dispose();
    }
    _descControllers.clear();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
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

                    TextField(
                      controller: _itemCountController,
                      keyboardType: TextInputType.number,
                      onEditingComplete: () {
                        if (!inputsLocked) {
                          _updateItemCount(_itemCountController.text);
                        }
                      },
                      enabled: !inputsLocked,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _sharedInputDecoration(
                        label: "إجمالي عدد القطع",
                        icon: Icons.format_list_numbered_rounded,
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
                              // معطّل لين تكتمل كل بيانات الصندوق
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
    );
  }
}
