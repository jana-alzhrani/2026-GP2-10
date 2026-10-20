import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_design.dart';
import 'welcome_page.dart';

class CourierMorePage extends StatefulWidget {
  final String userId;

  const CourierMorePage({super.key, required this.userId});

  @override
  State<CourierMorePage> createState() => _CourierMorePageState();
}

class _CourierMorePageState extends State<CourierMorePage> {
  Map userData = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future _fetchUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.userId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          userData = doc.data() ?? {};
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future _logout() async {
    final confirm = await AppDesign.showAppDialog(
      context: context,
      title: 'تسجيل الخروج',
      message: 'هل أنت متأكد من رغبتك في تسجيل الخروج من الحساب؟',
      confirmText: 'تسجيل الخروج',
    );

    if (confirm != true) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstName = userData['firstName'] ?? '';
    final lastName = userData['lastName'] ?? '';
    final phone = userData['phone'] ?? '';
    final role = userData['role'] ?? 'مندوب';

    final fullName = (firstName + ' ' + lastName).trim();
    final displayRole = role == 'courier' ? 'مندوب توصيل' : role;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDesign.background,
        appBar: AppBar(
          title: const Text('الملف الشخصي'),
          automaticallyImplyLeading: false,
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: AppPadding.screen.copyWith(top: 20, bottom: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppDesign.primary,
                            child: Text(
                              fullName.isNotEmpty ? fullName[0] : 'م',
                              style: const TextStyle(
                                color: AppDesign.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            fullName.isNotEmpty ? fullName : 'المندوب',
                            style: AppDesign.h1Style.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppDesign.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppDesign.secondary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              displayRole,
                              style: AppDesign.captionStyle.copyWith(
                                color: AppDesign.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'المعلومات الشخصية',
                      style: AppDesign.subtitleStyle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppDesign.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(label: 'الاسم الأول', value: firstName),
                    _buildInfoCard(label: 'اسم العائلة', value: lastName),
                    _buildInfoCard(label: 'رقم الجوال', value: phone),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _logout,
                      child: const Text(
                        'تسجيل الخروج',
                        style: TextStyle(
                          fontFamily: AppDesign.fontFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoCard({required String label, required String value}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppDesign.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesign.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppDesign.bodySecondaryStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value.isNotEmpty ? value : 'غير متوفر',
            style: AppDesign.bodyStyle.copyWith(
              color: AppDesign.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
