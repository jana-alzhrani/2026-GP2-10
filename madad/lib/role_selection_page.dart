import 'package:flutter/material.dart';
import 'app_design.dart';
import 'beneficiary_registration_page.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State {
  String? selectedRole; // 'donor' or 'beneficiary'

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDesign.background,
        body: SingleChildScrollView(
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    height: 280,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/madad_icon.jpeg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(
                    height: 280,
                    width: double.infinity,
                    decoration: BoxDecoration(),
                  ),
                  Positioned(
                    top: 40,
                    left: 10,
                    child: IconButton(
                      icon: Icon(Icons.arrow_forward, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Text(
                "سجل الآن",
                style: AppDesign.h1Style.copyWith(
                  color: AppDesign.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "اختر الدور المناسب لك",
                style: AppDesign.bodySecondaryStyle,
              ),

              const SizedBox(height: 20),

              // Donor Option Card
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: _buildRoleCard(
                  title: "عضو متبرع للملابس",
                  roleValue: 'donor',
                  icon: Icons.volunteer_activism_outlined,
                ),
              ),

              // Beneficiary Option Card
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: _buildRoleCard(
                  title: "عضو مستفيد من التبرعات",
                  roleValue: 'beneficiary',
                  icon: Icons.card_giftcard_outlined,
                ),
              ),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("يوجد لديك حساب؟", style: AppDesign.bodySecondaryStyle),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    child: const Text(
                      "تسجيل دخول",
                      style: TextStyle(
                        fontFamily: AppDesign.fontFamily,
                        color: AppDesign.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Confirm Button with Role Routing
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ElevatedButton(
                  onPressed: selectedRole == null
                      ? null
                      : () {
                          if (selectedRole == 'beneficiary') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const BeneficiaryRegistrationPage(),
                              ),
                            );
                          } else {
                            Navigator.pushNamed(
                              context,
                              '/signup',
                              arguments: selectedRole,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppDesign.primary,
                    disabledBackgroundColor: AppDesign.secondary.withOpacity(
                      0.3,
                    ),
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    "تأكيد",
                    style: AppDesign.buttonOnPrimaryStyle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String roleValue,
    required IconData icon,
  }) {
    final bool isSelected = selectedRole == roleValue;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedRole = roleValue;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppDesign.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? AppDesign.primary : AppDesign.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppDesign.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? AppDesign.primary
                      : AppDesign.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: AppDesign.subtitleStyle.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? AppDesign.primary
                        : AppDesign.textPrimary,
                  ),
                ),
              ],
            ),
            Radio(
              value: roleValue,
              groupValue: selectedRole,
              activeColor: AppDesign.primary,
              onChanged: (value) {
                setState(() {
                  selectedRole = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
