// ============================================================
// نظام التوصية (V4 type-aware + FashionCLIP)
//
// 1) السيرفر يحسب "بصمة" كل قطعة (128 رقم) مرة وحدة، ونحفظها في items.embedding
// 2) هنا داخل التطبيق نرتب القطع لحظياً بنفس معادلة الموديل:
//    score = cosine(e_a × m, e_b × m)   (m = قناع زوج الأنواع من v4_masks.json)
// الرقم للترتيب بس، ما نعرضه كنسبة.
// ============================================================
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'app_design.dart';
import 'Beneficiary_view_item_page.dart';

class Recommender {
   static const String serverUrl = '';
  static const String appSecret = '';

  // أنواع التطبيق (عربي) -> أنواع الموديل (إنجليزي). الثوب والشماغ والعباية تحت (proxyType).
  static const Map<String, String> arToModelType = {
    'قميص': 'Shirt',
    'تيشيرت': 'T-Shirt',
    'كنزة': 'Sweater',
    'بنطلون': 'Pants',
    'تنورة': 'Skirt',
    'فستان': 'Dress',
    'جاكيت': 'Jacket',
    'معطف': 'Coat',
    'حذاء': 'Shoe',
    'حقيبة': 'Bag',
    'قبعة': 'Hat',
    'شال': 'Shawl',
    'نظارة': 'Glasses',
    'ساعة': 'Watch',
    'حزام': 'Belt',
    'قفازات': 'Gloves',
  };

  static Map<String, int>? _typeIndex;
  static List<List<List<double>>>? _masks;
  static Map<String, List<String>>? _goWith;

  static Future<void> _load() async {
    if (_masks != null) return;
    final m = jsonDecode(await rootBundle.loadString('assets/model/v4_masks.json'));
    final types = List<String>.from(m['types']);
    _typeIndex = {for (var i = 0; i < types.length; i++) types[i]: i};
    _masks = (m['masks'] as List)
        .map((row) => (row as List)
            .map((v) => (v as List).map((x) => (x as num).toDouble()).toList())
            .toList())
        .toList();
    final g = jsonDecode(await rootBundle.loadString('assets/model/type_cooccurrence.json'))
        as Map<String, dynamic>;
    _goWith = g.map((k, v) => MapEntry(k, List<String>.from(v)));
  }

  // القطع السعودية مو موجودة في بيانات تدريب الموديل (Polyvore)،
  // فنعاملها كأقرب نوع: الثوب والعباية قطعة كاملة مثل الفستان، والشماغ غطاء راس مثل القبعة.
  static const Map<String, String> proxyType = {
    'ثوب': 'Dress',
    'عباية': 'Dress',
    'شماغ': 'Hat',
  };

  // وش يطلع معها (بالترتيب): إكسسوارات وأحذية تكمّل اللبسة
  static const Map<String, List<String>> saudiGoWith = {
    'ثوب': ['شماغ', 'حذاء', 'ساعة', 'نظارة'],
    'عباية': ['حقيبة', 'حذاء', 'شال', 'نظارة', 'ساعة'],
    'شماغ': ['ثوب', 'حذاء', 'ساعة', 'نظارة'],
  };

  static String? modelTypeOf(String? arType) =>
      arToModelType[arType] ?? proxyType[arType];

  static bool supports(String? arType) => modelTypeOf(arType) != null;

  static List<double>? _vec(dynamic v) {
    if (v is! List || v.isEmpty) return null;
    return v.map((x) => (x as num).toDouble()).toList();
  }

  /// نفس معادلة الموديل بالضبط
  static double score(List<double> ea, List<double> eb, String ta, String tb) {
    final mask = _masks![_typeIndex![ta]!][_typeIndex![tb]!];
    double dot = 0, na = 0, nb = 0;
    for (var k = 0; k < mask.length; k++) {
      final x = ea[k] * mask[k], y = eb[k] * mask[k];
      dot += x * y;
      na += x * x;
      nb += y * y;
    }
    if (na == 0 || nb == 0) return -1;
    return dot / (math.sqrt(na) * math.sqrt(nb));
  }

  /// يطلب البصمة من السيرفر ويحفظها في القطعة. ما يرمي خطأ (التوصية ميزة إضافية).
  static Future<List<double>?> computeAndSaveEmbedding(
    DocumentReference<Map<String, dynamic>> itemRef,
    String imageUrl,
    String description,
  ) async {
    if (serverUrl.isEmpty || imageUrl.trim().isEmpty) return null;
    try {
      final res = await http
          .post(
            Uri.parse('$serverUrl/embed'),
            headers: {'Content-Type': 'application/json', 'x-app-secret': appSecret},
            body: jsonEncode({'imageUrl': imageUrl, 'description': description}),
          )
          .timeout(const Duration(seconds: 90));
      if (res.statusCode != 200) {
        debugPrint('EMBED ERROR ${res.statusCode}: ${res.body}');
        return null;
      }
      final e = _vec(jsonDecode(res.body)['embedding']);
      if (e != null) {
        try {
          await itemRef.update({'embedding': e});
        } catch (err) {
          debugPrint('EMBED SAVE ERROR: $err'); // نرجّع البصمة حتى لو ما انحفظت
        }
      }
      return e;
    } catch (e) {
      debugPrint('EMBED ERROR: $e');
      return null;
    }
  }

  /// لكل قطعة جديدة في الصندوق (بعد الحفظ). ما ننتظره عشان ما يتأخر المتبرع.
  static void embedInBackground(List<Map<String, dynamic>> items) {
    for (final it in items) {
      unawaited(computeAndSaveEmbedding(
        it['ref'] as DocumentReference<Map<String, dynamic>>,
        (it['imageUrl'] ?? '').toString(),
        (it['description'] ?? '').toString(),
      ));
    }
  }

  /// أفضل [perType] قطع من كل نوع يناسب القطعة المعروضة
  static Future<List<Map<String, dynamic>>> rank({
    required Map<String, dynamic> query,
    required List<Map<String, dynamic>> candidates,
    int perType = 2,
    int maxTotal = 8,
  }) async {
    await _load();
    final custom = saudiGoWith[query['type']];
    if (custom != null) return _rankSaudi(query, candidates, custom, perType, maxTotal);
    final tq = arToModelType[query['type']];
    final eq = _vec(query['embedding']);
    if (tq == null || eq == null || !_typeIndex!.containsKey(tq)) return [];
    final wanted = _goWith![tq] ?? [];

    final byType = <String, List<Map<String, dynamic>>>{};
    for (final c in candidates) {
      final tc = arToModelType[c['type']];
      final ec = _vec(c['embedding']);
      if (tc == null || ec == null || !wanted.contains(tc) || !_typeIndex!.containsKey(tc)) continue;
      byType.putIfAbsent(tc, () => []).add({...c, '_score': score(eq, ec, tq, tc)});
    }
    final out = <Map<String, dynamic>>[];
    for (final t in wanted) {            // الأنواع الأكثر ظهوراً مع القطعة أولاً
      final list = byType[t];
      if (list == null) continue;
      list.sort((a, b) => (b['_score'] as double).compareTo(a['_score'] as double));
      out.addAll(list.take(perType));
      if (out.length >= maxTotal) break;
    }
    return out.take(maxTotal).toList();
  }

  // الثوب والعباية والشماغ: نفس معادلة الموديل بالنوع الأقرب، والأنواع من قائمتنا
  static List<Map<String, dynamic>> _rankSaudi(
    Map<String, dynamic> query,
    List<Map<String, dynamic>> candidates,
    List<String> wanted,
    int perType,
    int maxTotal,
  ) {
    final tq = modelTypeOf(query['type']);
    final eq = _vec(query['embedding']);
    if (tq == null || eq == null || !_typeIndex!.containsKey(tq)) return [];
    final byType = <String, List<Map<String, dynamic>>>{};
    for (final c in candidates) {
      final ar = (c['type'] ?? '').toString();
      final tc = modelTypeOf(ar);
      final ec = _vec(c['embedding']);
      if (tc == null || ec == null || !wanted.contains(ar) || !_typeIndex!.containsKey(tc)) continue;
      byType.putIfAbsent(ar, () => []).add({...c, '_score': score(eq, ec, tq, tc)});
    }
    final out = <Map<String, dynamic>>[];
    for (final t in wanted) {
      final list = byType[t];
      if (list == null) continue;
      list.sort((a, b) => (b['_score'] as double).compareTo(a['_score'] as double));
      out.addAll(list.take(perType));
      if (out.length >= maxTotal) break;
    }
    return out.take(maxTotal).toList();
  }
}

// ============================================================
// قسم "قطع تناسبها" في صفحة تفاصيل القطعة (لحظي)
// ============================================================
class MatchingItemsSection extends StatefulWidget {
  final String itemId;
  final Map<String, dynamic> item; // فيها type, gender, ageGroup, imageUrl, description
  final String userId;

  const MatchingItemsSection({
    super.key,
    required this.itemId,
    required this.item,
    required this.userId,
  });

  @override
  State<MatchingItemsSection> createState() => _MatchingItemsSectionState();
}

class _MatchingItemsSectionState extends State<MatchingItemsSection> {
  final _db = FirebaseFirestore.instance;
  final Map<String, Map<String, dynamic>> _boxCache = {};
  final Set<String> _requested = {}; // قطع طلبنا بصمتها (عشان ما نكرر)
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<Map<String, dynamic>> _results = [];
  List<double>? _queryEmbedding;

  static String _ageLabel(dynamic v) =>
      v is Map ? (v['label'] ?? '').toString() : (v ?? '').toString();

  // ترتيب الفئات العمرية والمقاسات (نفس القوائم في صفحة إضافة التبرع)
  static const _ageOrder = [
    'رضّع (0-2)', 'أطفال صغار (3-5)', 'أطفال (6-9)', 'أطفال (10-15)', 'بالغون'
  ];
  static const _sizeOrder = ['XS - S', 'S - M', 'M - L', 'L - XL'];
  // الملابس اللي لها مقاس. الأحذية والحقائب والإكسسوارات ما يهمها مقاس الملابس
  static const _sized = {
    'قميص', 'تيشيرت', 'كنزة', 'بنطلون', 'تنورة', 'فستان', 'جاكيت', 'معطف', 'ثوب', 'عباية'
  };

  // العمر قريب: نفس الفئة أو اللي جنبها مباشرة، والأطفال ما يختلطون مع البالغين
  static bool _ageClose(String a, String b) {
    if (a.isEmpty || b.isEmpty) return true;
    final i = _ageOrder.indexOf(a), j = _ageOrder.indexOf(b);
    if (i < 0 || j < 0) return a == b;
    final adultA = a == 'بالغون', adultB = b == 'بالغون';
    if (adultA || adultB) return adultA == adultB;
    return (i - j).abs() <= 1;
  }

  // المقاس قريب (للبالغين): نفس المقاس أو اللي جنبه، مثل S - M مع M - L
  static bool _sizeClose(String a, String b) {
    if (a.isEmpty || b.isEmpty) return true;
    final i = _sizeOrder.indexOf(a), j = _sizeOrder.indexOf(b);
    if (i < 0 || j < 0) return true;
    return (i - j).abs() <= 1;
  }

  @override
  void initState() {
    super.initState();
    if (Recommender.supports(widget.item['type'])) _start();
  }

  Future<void> _start() async {
    // بصمة القطعة المعروضة (لو قطعة قديمة ما عندها، نحسبها الحين)
    _queryEmbedding = Recommender._vec(widget.item['embedding']);
    _queryEmbedding ??= await Recommender.computeAndSaveEmbedding(
      _db.collection('items').doc(widget.itemId),
      (widget.item['imageUrl'] ?? '').toString(),
      (widget.item['description'] ?? '').toString(),
    );
    if (_queryEmbedding == null || !mounted) return;

    // snapshots: المحجوزة تختفي والجديدة تطلع فوراً
    _sub = _db
        .collection('items')
        .where('status', isEqualTo: 'available')
        .snapshots()
        .listen(_onItems, onError: (e) => debugPrint('RECO STREAM ERROR: $e'));
  }

  Future<void> _onItems(QuerySnapshot<Map<String, dynamic>> snap) async {
    final gender = (widget.item['gender'] ?? '').toString();
    final age = _ageLabel(widget.item['ageGroup']);

    final myBoxId = (widget.item['boxId'] ?? '').toString();
    final newBoxIds = [
      myBoxId,
      ...snap.docs.map((d) => (d.data()['boxId'] ?? '').toString()),
    ].where((id) => id.isNotEmpty && !_boxCache.containsKey(id)).toSet();
    await Future.wait(newBoxIds.map((id) async {
      try {
        final s = await _db.collection('donation_boxes').doc(id).get();
        if (s.exists && s.data() != null) _boxCache[id] = s.data()!;
      } catch (e) {
        debugPrint('BOX FETCH ERROR ($id): $e');
      }
    }));

    final mySize = (_boxCache[myBoxId]?['generalSize'] ?? '').toString();

    final candidates = <Map<String, dynamic>>[];
    for (final d in snap.docs) {
      if (d.id == widget.itemId) continue;
      final data = d.data();
      if (!Recommender.supports(data['type'])) continue;
      final box = _boxCache[(data['boxId'] ?? '').toString()];
      final g = (box?['gender'] ?? data['gender'] ?? '').toString();
      final a = _ageLabel(box?['ageGroup'] ?? data['ageGroup']);
      if (gender.isNotEmpty && g.isNotEmpty && g != gender) continue; // نفس الجنس
      if (!_ageClose(age, a)) continue;                                // عمر قريب
      if (age == 'بالغون' &&
          _sized.contains(widget.item['type']) &&
          _sized.contains(data['type']) &&
          !_sizeClose(mySize, (box?['generalSize'] ?? '').toString())) continue; // مقاس قريب (للملابس بس)

      if (data['embedding'] == null && _requested.add(d.id)) {
        // قطعة قديمة أو فشل حسابها وقت الرفع: نحسبها بالخلفية، وتطلع بالتحديث الجاي
        unawaited(Recommender.computeAndSaveEmbedding(
          d.reference,
          (data['imageUrl'] ?? '').toString(),
          (data['description'] ?? '').toString(),
        ));
        continue;
      }
      candidates.add({...data, 'itemId': d.id, 'boxId': (data['boxId'] ?? '').toString()});
    }

    final ranked = await Recommender.rank(
      query: {'type': widget.item['type'], 'embedding': _queryEmbedding},
      candidates: candidates,
    );
    if (mounted) setState(() => _results = ranked);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_results.isEmpty) return const SizedBox.shrink(); // نوع مو مدعوم أو ما فيه قطع
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDesign.spaceLG),
        Text('قطع تناسبها', style: AppDesign.h2Style.copyWith(color: AppDesign.textPrimary)),
        const SizedBox(height: AppDesign.spaceSM),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _results.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppDesign.spaceMD),
            itemBuilder: (context, i) {
              final r = _results[i];
              final url = (r['imageUrl'] ?? '').toString();
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BeneficiaryViewItemPage(
                      itemId: r['itemId'],
                      boxId: r['boxId'],
                      userId: widget.userId,
                    ),
                  ),
                ),
                child: Container(
                  width: 120,
                  decoration: AppDesign.primaryCardDecoration,
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppDesign.radiusMD),
                          ),
                          child: url.isEmpty
                              ? Container(color: AppDesign.surfaceAlt)
                              : Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (_, __, ___) =>
                                      Container(color: AppDesign.surfaceAlt),
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(AppDesign.spaceSM),
                        child: Text(
                          (r['type'] ?? '').toString(),
                          style: AppDesign.bodyStyle.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
