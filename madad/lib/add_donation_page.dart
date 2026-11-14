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


final List<String> sizeRanges = [
  "XS - S",
  "S - M",
  "M - L",
  "L - XL",
];
String? generalSize;

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
        'isValid': false,
        'error': null,
      },
    );

    remainingItems -= itemsInThisBox;
  }

  setState(() {});
}
  


Future<void> _pickItemImage(int box, int index) async {
  final picker = ImagePicker();
  final XFile? image = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 60,
  );
  if (image != null) {
    final bytes = await image.readAsBytes();
    setState(() {
      boxes[box]![index]['image'] = bytes;
    });
    _verifyImageWithGemini(
      box,
      index,
      bytes,
      image.mimeType, 
    );
  }
}

Future<Map<String, String>> uploadImage(
  Uint8List bytes,
  String path,
) async {
  final ref = FirebaseStorage.instance
      .ref()
      .child(path);
  await ref.putData(bytes);
  final url = await ref.getDownloadURL();
  return {
    'url': url,
    'path': ref.fullPath,
  };
}
bool canOpenBox() {
    if (selectedGender == null) return false;
    if (selectedAgeGroup == null) return false;

    if (ageNeedsSize() && generalSize == null) {
      return false;
    }

    return true;
  }

  Future<void> _verifyImageWithGemini(int box, int index, Uint8List imageBytes, String? mimeType) async {
    setState(() {

      boxes[box]![index]['error'] = "جاري الفحص...";
    });
    final String url =
        'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=$_apiKey';
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
"""

                },

{"inline_data": {
  "mime_type": "image/jpeg",
  "data": base64Image
}}
              ]

            }

          ]

        }),

      );



      if (response.statusCode == 200) {

        final data = jsonDecode(response.body);

        String result = data['candidates'][0]['content']['parts'][0]['text'];

      setState(() {
  String cleaned = result.trim().toLowerCase();

  if (cleaned.startsWith("yes")) {

    String? detectedType;

    // استخراج النوع
    if (cleaned.contains("-")) {
      String typeEng = cleaned.split("-")[1].trim();
      detectedType = typeMap[typeEng];
    }

    boxes[box]![index]['isValid'] = true;
    boxes[box]![index]['error'] = null;

    // تعيين النوع تلقائي
    if (detectedType != null && boxes[box]![index]['type'] == null) {
      boxes[box]![index]['type'] = detectedType;
    }

   AppDesign.showImageValidSnackBar(
  context,
  "الصورة صالحة",
);

  } else {

    boxes[box]![index]['image'] = null;
    boxes[box]![index]['type'] = null;
    boxes[box]![index]['isValid'] = false;
    boxes[box]![index]['size'] = null;
    boxes[box]![index]['error'] = null;

   AppDesign.showImageInvalidSnackBar(
  context,
  "الصورة غير صالحة!",
);
  }
});
      } else {

        setState(() {

          boxes[box]![index]['error'] = "فشل الفحص: ${response.statusCode}";

        });

      }
      
      


    } catch (e) {

      setState(() {

        boxes[box]![index]['error'] = "فشل الفحص: $e";

      });

    }

  }


Future<void> createDonationIfNeeded() async {
  if (donationId != null) return;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final doc = await firestore.collection('donations').add({
    'donorID': user.uid,
    'gender': selectedGender ?? "",
    'ageGroup': selectedAgeGroup != null
        ? selectedAgeGroup!['label']
        : "",
        'generalSize': generalSize ?? "",
    'numberOfItems': totalItems,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(), 
  });

  donationId = doc.id;
  print("NEW donationId => $donationId");
}

bool validateBoxBeforeSave(int box) {
  final items = boxes[box]!;

  for (var item in items) {
    if (item['image'] == null) return false;
    if (item['type'] == null) return false;
    if (item['isValid'] != true) return false;

    if (item['type'] == "حذاء" && item['size'] == null) {
      return false;
    }
  }

  return true;
}Future<void> _submitBox(int box) async {
  if (!validateBoxBeforeSave(box)) {
    AppDesign.showErrorSnackBar(
  context,
  "يرجى إكمال جميع الحقول",
);
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

    List<Map<String, dynamic>> uploadedItems = [];

    final items = boxes[box]!;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];

      final filePath =
          'donations/$donationId/boxes/box_$box/item_$i.jpg';
          print("STORAGE PATH TEST => donations/$donationId/test.jpg");

      // 1) رفع الصورة
     final Uint8List imageBytes = item['image'];

final uploaded = await uploadImage(
  item['image'],
  filePath,
);

      // 2) تجهيز البيانات
      uploadedItems.add({
        'type': item['type'],
        'size': item['type'] == "حذاء" ? item['size'] : null,
       'imageUrl': uploaded['url'],
'imagePath': uploaded['path'],
      });
    }

    // 3) حفظ في Firestore
    await firestore.collection('donation_boxes').add({
      'donationId': donationId,
      'userId': user.uid,
      'boxNumber': box,
      'gender': selectedGender,
      'ageGroup': selectedAgeGroup,
      'generalSize': generalSize,
      'status': 'draft',
      'items': uploadedItems,
      'timestamp': FieldValue.serverTimestamp(),
    });
    print("DONATION ID: $donationId");
print("BOX: $box");
print("ITEMS: ${items.length}");
print("IMAGE NULL?: ${items[0]['image'] == null}");

    // 4) تحديث UI
    setState(() {
      boxes[box] = List.generate(
        boxes[box]!.length,
        (_) => {
          'image': null,
          'type': null,
          'size': null,
          'isValid': false,
          'error': null,
        },
      );

      savedBoxes.add(box);
      openedBox = null;
    });

   
  } catch (e) {
    AppDesign.showErrorSnackBar(
  context,
  "فشل الحفظ: $e",
);
    
  }
}

  bool allBoxesSaved() {

    return savedBoxes.length == totalBoxes;

  }
  Future<void> _showLogoutDialog() async {
  final confirm = await AppDesign.showAppDialog(
    context: context,
    title: "الرجوع",
    message: "هل أنتِ متأكدة من الرجوع؟ لن يتم حفظ التبرع الحالي.",
  );

  if (!confirm) return;

  final user = FirebaseAuth.instance.currentUser;

  if (donationId != null) {
    final boxesSnap = await FirebaseFirestore.instance
        .collection('donation_boxes')
        .where('donationId', isEqualTo: donationId)
        .get();

    for (var doc in boxesSnap.docs) {
      await doc.reference.delete();
    }

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

            /// الجنس
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
                  : (v) => setState(() => selectedGender = v),
              value: selectedGender,
            ),

            AppGap.md,

            /// العمر
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
                  : (v) => setState(() => selectedAgeGroup = v),
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
    .map((e) => DropdownMenuItem(
          value: e,
          child: Text(e),
        ))
    .toList(),
    
    onChanged: inputsLocked
        ? null
        : (v) => setState(() => generalSize = v),
  ),
],
            AppGap.md,

            /// عدد القطع
          TextField(
  controller: _itemCountController,
  keyboardType: TextInputType.number,
  enabled: !inputsLocked,
  onChanged: inputsLocked ? null : _updateItemCount,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
  ],decoration: InputDecoration(
  labelText: "إجمالي عدد القطع",
  errorText: itemCountError,

  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
  ),

  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.blue),
  ),

  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.red),
  ),

  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.red),
  ),
),
),

            AppGap.lg,

            /// الصناديق
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
                            borderRadius:
                                BorderRadius.circular(AppDesign.radiusLG),
                            gradient: LinearGradient(
                              colors: isSaved
                                  ? [AppDesign.success, AppDesign.primary]
                                  : [
                                      AppDesign.softGreen.withOpacity(0.2),
                                      AppDesign.softGreen
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
                                  style: AppDesign.subtitleStyle
                                      .copyWith(color: Colors.white),
                                ),

                                Text(
                                  "${boxes[boxNum]?.length ?? 0} قطع",
                                  style: AppDesign.captionStyle
                                      .copyWith(color: Colors.white70),
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

            /// داخل الصندوق
            if (openedBox != null)
              Column(
                children: [

                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() => openedBox = null);
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text("رجوع"),
                      ),
                    ],
                  ),

                  AppGap.sm,

                  ...boxes[openedBox]!.asMap().entries.map((entry) {
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
                                  onTap: () =>
                                      _pickItemImage(openedBox!, idx),
                                  child: Container(
                                    height: 90,
                                    width: 90,
                                    decoration: BoxDecoration(
                                      color: AppDesign.surfaceAlt,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppDesign.border),
                                    ),
                                    child: item['image'] == null
                                        ? const Icon(Icons.upload)
                                        : ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Image.memory(item['image']),
                                          ),
                                  ),
                                ),

                                AppGap.wMD,

                                Expanded(
                                  child: Column(
                                    children: [

                                      /// نوع القطعة
                                      DropdownButton<String>(
                                        hint: const Text("نوع القطعة"),
                                        value: item['type'],
                                        isExpanded: true,
                                        items: [
                                          "قميص",
                                          "بنطلون",
                                          "فستان",
                                          "معطف",
                                          "حذاء",
                                          "حقيبة",
                                          "قبعة"
                                        ]
                                            .map((e) => DropdownMenuItem(
                                                value: e, child: Text(e)))
                                            .toList(),
                                        onChanged: (v) {
                                          setState(() {
                                            boxes[openedBox]![idx]['type'] = v;
                                            boxes[openedBox]![idx]['size'] = null;
                                          });
                                        },
                                      ),

                                  
                                      ///  مقاس الحذاء
                                      if (item['type'] == "حذاء")
                                        DropdownButton<String>(
                                          hint: const Text("مقاس الحذاء"),
                                          value: item['size'],
                                          isExpanded: true,
                                          items: List.generate(
                                            28,
                                            (i) => (20 + i).toString(),
                                          )
                                              .map((e) => DropdownMenuItem(
                                                  value: e, child: Text(e)))
                                              .toList(),
                                          onChanged: (v) {
                                            setState(() {
                                              boxes[openedBox]![idx]['size'] = v;
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
                                style: AppDesign.captionStyle
                                    .copyWith(color: AppDesign.error),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),

                  AppGap.lg,

                  ElevatedButton(
                    onPressed: () async {
                      await _submitBox(openedBox!);
                    },
                    child: const Text("حفظ الصندوق"),
                  ),
                ],
              ),

            AppGap.lg,

           
ElevatedButton(
onPressed: (totalBoxes > 0 && allBoxesSaved())
    ? () async {
        try {
          final user = FirebaseAuth.instance.currentUser;

          await FirebaseFirestore.instance
              .collection('donations')
              .doc(donationId ?? user!.uid)
              .update({
            'donorID': user!.uid,
            'gender': selectedGender ?? "",
            'ageGroup': selectedAgeGroup?['label'] ?? "",
            'generalSize': generalSize ?? "",
            'numberOfItems': totalItems,
            'updatedAt': FieldValue.serverTimestamp(),
            'status': 'draft',
          });

          final dataToSave = {
            'donationId': donationId,
          };

          print(dataToSave);

          await firestore.collection('donation_boxes').add(dataToSave);

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
            arguments: user?.uid ?? '',
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
