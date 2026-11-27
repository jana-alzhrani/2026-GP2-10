import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_design.dart';

class DonorHomePage extends StatefulWidget {
  final String userId;

  const DonorHomePage({super.key, required this.userId});

  @override
  State<DonorHomePage> createState() => _DonorHomePageState();
}

class _DonorHomePageState extends State<DonorHomePage> {
  final PageController _pageController = PageController(viewportFraction: 0.90);

  int _currentCardIndex = 0;
  int _bottomNavIndex = 0;

  String userName = 'مستخدم';
  int donorsCount = 0;
  int clothingCount = 0;
  int familiesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('Users').doc(widget.userId).get(),
        FirebaseFirestore.instance.collection('stats').doc('public').get(),
      ]);

      if (!mounted) return;

      final userDoc = results[0];
      final statsDoc = results[1];

      String fetchedUserName = 'مستخدم';

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        final firstName = (data['firstName'] ?? '').toString().trim();
        final lastName = (data['lastName'] ?? '').toString().trim();
        final fullName = '$firstName $lastName'.trim();
        fetchedUserName = fullName.isEmpty ? 'مستخدم' : fullName;
      }

      final stats = statsDoc.data() ?? {};

      int readCount(String key) {
        final value = stats[key];
        if (value is num) return value.toInt();
        return int.tryParse(value?.toString() ?? '') ?? 0;
      }

      setState(() {
        userName = fetchedUserName;
        donorsCount = readCount('donorsCount');
        clothingCount = readCount('clothingCount');
        familiesCount = readCount('familiesCount');
      });
    } catch (e) {
      debugPrint('Error loading home data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDesign.background,
        body: SafeArea(
          child: RefreshIndicator(
            color: AppDesign.primary,
            onRefresh: _loadHomeData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppPadding.screen.copyWith(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  AppGap.xl,
                  _buildCardsSlider(),
                  AppGap.md,
                  _buildSliderDots(),
                  AppGap.lg,
                  _buildDonateSection(),
                  const SizedBox(height: 28),
                  _buildStatsSection(),
                  AppGap.section,
                  _buildVerse(),
                  AppGap.sm,
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildHeader() {
    final String firstLetter = userName.trim().isNotEmpty
        ? userName.trim()[0]
        : 'م';

    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppDesign.primary,
          child: Text(
            firstLetter,
            style: const TextStyle(
              color: AppDesign.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ),
        AppGap.wMD,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مرحبًا',
                style: AppDesign.bodyStyle.copyWith(
                  color: AppDesign.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                userName,
                style: AppDesign.h1Style.copyWith(
                  color: AppDesign.primary,
                  fontSize: 31,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardsSlider() {
    final List<_HomeCardData> cards = [
      const _HomeCardData(
        title: 'تبرعك يصنع فرقًا',
        subtitle:
            'من خلال مدد يمكنك دعم الأسر المستفيدة والمساهمة في توفير الكسوة بطريقة سهلة وواضحة.',
        background: AppDesign.primary,
        titleColor: AppDesign.white,
        subtitleColor: AppDesign.white,
        accentColor: AppDesign.softGreen,
        icon: Icons.volunteer_activism_rounded,
      ),
      const _HomeCardData(
        title: 'أثر عطائك',
        subtitle:
            'كل مساهمة منك تقرّب الخير إلى أسرة مستفيدة وتمنحها دعمًا يصل في وقته.',
        background: AppDesign.secondary,
        titleColor: AppDesign.white,
        subtitleColor: AppDesign.white,
        accentColor: AppDesign.surfaceAlt,
        icon: Icons.favorite_rounded,
      ),
      const _HomeCardData(
        title: 'خطوة منك.. حياة أدفأ لهم',
        subtitle:
            'كن جزءًا من عطاء يصل لمستحقيه ويصنع أثرًا حقيقيًا يستمر مع كل مساهمة.',
        background: AppDesign.primary,
        titleColor: AppDesign.white,
        subtitleColor: AppDesign.white,
        accentColor: AppDesign.surfaceAlt,
        icon: Icons.family_restroom_rounded,
      ),
    ];

    return SizedBox(
      height: 260,
      child: PageView.builder(
        controller: _pageController,
        itemCount: cards.length,
        onPageChanged: (index) {
          setState(() {
            _currentCardIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final card = cards[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _DonationCard(data: card),
          );
        },
      ),
    );
  }

  Widget _buildSliderDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentCardIndex == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentCardIndex == index
                ? AppDesign.primary
                : AppDesign.border,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _buildDonateSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: AppDesign.white,
        borderRadius: BorderRadius.circular(AppDesign.radiusXL),
        border: Border.all(color: AppDesign.border),
        boxShadow: [
          BoxShadow(
            color: AppDesign.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: -20,
            bottom: -9,
            child: Image.asset(
              'assets/images/donate_branch.png',
              width: 145,
              fit: BoxFit.contain,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppDesign.softGreen.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
                      color: AppDesign.primary,
                      size: 20,
                    ),
                  ),
                  AppGap.wSM,
                  Expanded(
                    child: Text(
                      'ابدأ رحلتك في العطاء من هنا، وساهم في دعم الأسر المستفيدة.',
                      style: AppDesign.bodyStyle.copyWith(
                        color: AppDesign.primary.withOpacity(0.85),
                        fontSize: 14.5,
                        height: 1.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              AppGap.xl,
              Center(
                child: SizedBox(
                  width: 240,
                  height: AppDesign.buttonHeightLG,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/addDonation',
                        arguments: widget.userId,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesign.softGreen,
                      foregroundColor: AppDesign.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDesign.radiusXL),
                      ),
                    ),
                    child: Text(
                      'ساهم الآن',
                      style: AppDesign.buttonOnPrimaryStyle.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إحصائيات البرنامج',
          style: AppDesign.h1Style.copyWith(
            color: AppDesign.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        AppGap.lg,
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  title: 'عدد المتبرعين',
                  value: '$donorsCount',
                  icon: Icons.volunteer_activism_outlined,
                ),
              ),
              AppGap.wMD,
              Expanded(
                child: _StatCard(
                  title: 'الكسوات المقدمة',
                  value: '$clothingCount',
                  icon: Icons.checkroom_rounded,
                ),
              ),
            ],
          ),
        ),
        AppGap.md,
        _StatCard(
          title: 'الأسر المستفيدة',
          value: '$familiesCount',
          icon: Icons.home_work_rounded,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildVerse() {
    return Center(
      child: Text(
        '﴿ لَن تَنَالُوا الْبِرَّ حَتّىٰ تُنفِقُوا مِمّا تُحِبّونَ ﴾',
        textAlign: TextAlign.center,
        style: AppDesign.subtitleStyle.copyWith(
          color: AppDesign.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: AppDesign.white,
        borderRadius: BorderRadius.circular(AppDesign.radiusXL),
        boxShadow: [
          BoxShadow(
            color: AppDesign.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: NavigationBar(
        height: 78,
        selectedIndex: _bottomNavIndex,
        backgroundColor: Colors.transparent,
        indicatorColor: AppDesign.secondary.withOpacity(0.16),
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          if (index == _bottomNavIndex && index == 0) return;

          setState(() {
            _bottomNavIndex = index;
          });

          if (index == 1) {
            Navigator.pushReplacementNamed(
              context,
              '/viewDonation',
              arguments: widget.userId,
            );
          } else if (index == 2) {
            Navigator.pushReplacementNamed(
              context,
              '/donorMore',
              arguments: widget.userId,
            );
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: AppDesign.primary),
            selectedIcon: Icon(Icons.home_rounded, color: AppDesign.primary),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.volunteer_activism_outlined,
              color: AppDesign.primary,
            ),
            selectedIcon: Icon(
              Icons.volunteer_activism_rounded,
              color: AppDesign.primary,
            ),
            label: 'تبرعاتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded, color: AppDesign.primary),
            selectedIcon: Icon(
              Icons.more_horiz_rounded,
              color: AppDesign.primary,
            ),
            label: 'المزيد',
          ),
        ],
      ),
    );
  }
}

class _HomeCardData {
  final String title;
  final String subtitle;
  final Color background;
  final Color titleColor;
  final Color subtitleColor;
  final Color accentColor;
  final IconData icon;

  const _HomeCardData({
    required this.title,
    required this.subtitle,
    required this.background,
    required this.titleColor,
    required this.subtitleColor,
    required this.accentColor,
    required this.icon,
  });
}

class _DonationCard extends StatelessWidget {
  final _HomeCardData data;

  const _DonationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final subtitleColor = data.subtitleColor.withOpacity(0.92);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: data.background,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppDesign.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -18,
            left: -8,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: data.accentColor.withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            right: -10,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: data.accentColor.withOpacity(0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: AppDesign.white.withOpacity(0.14),
                  child: Icon(data.icon, color: data.titleColor, size: 24),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                data.title,
                style: TextStyle(
                  color: data.titleColor,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  data.subtitle,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 15.5,
                    height: 1.65,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool fullWidth;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppDesign.white,
        borderRadius: BorderRadius.circular(AppDesign.radiusXL),
        border: Border.all(color: AppDesign.border),
        boxShadow: [
          BoxShadow(
            color: AppDesign.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppDesign.secondary.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppDesign.primary, size: 21),
          ),
          AppGap.wMD,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: AppDesign.bodyStyle.copyWith(
                    color: AppDesign.textSecondary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: AppDesign.h1Style.copyWith(
                    color: AppDesign.primary,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
