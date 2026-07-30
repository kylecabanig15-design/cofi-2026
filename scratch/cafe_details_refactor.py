import re

def update_cafe_details():
    path = 'lib/features/cafe/cafe_details_screen.dart'
    with open(path, 'r') as f:
        content = f.read()
        
    # 1. Imports
    if "import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';" not in content:
        content = content.replace(
            "import 'package:intl/intl.dart';",
            "import 'package:intl/intl.dart';\nimport 'package:tutorial_coach_mark/tutorial_coach_mark.dart';\nimport 'package:shared_preferences/shared_preferences.dart';"
        )

    # 2. Convert to StatefulWidget
    old_class = """class CafeDetailsScreen extends StatelessWidget {
  final String? shopId;
  final Map<String, dynamic>? shop;

  const CafeDetailsScreen({super.key, this.shopId, this.shop});

  @override
  Widget build(BuildContext context) {"""
    
    new_class = """class CafeDetailsScreen extends StatefulWidget {
  final String? shopId;
  final Map<String, dynamic>? shop;

  const CafeDetailsScreen({super.key, this.shopId, this.shop});

  @override
  State<CafeDetailsScreen> createState() => _CafeDetailsScreenState();
}

class _CafeDetailsScreenState extends State<CafeDetailsScreen> {
  TutorialCoachMark? _tutorialCoachMark;
  final GlobalKey _logVisitKey = GlobalKey();
  final GlobalKey _reviewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _checkTutorial();
  }

  Future<void> _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('hasSeenCafeDetailsTutorial') ?? false;
    if (!hasSeen) {
      // Small delay to ensure widgets are built
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _showTutorial();
        }
      });
    }
  }

  void _showTutorial() {
    _tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Colors.black,
      paddingFocus: 10,
      opacityShadow: 0.8,
      hideSkip: true,
      onFinish: () => _markTutorialSeen(),
      onSkip: () {
        _markTutorialSeen();
        return true;
      },
    )..show(context: context);
  }

  Future<void> _markTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenCafeDetailsTutorial', true);
  }

  List<TargetFocus> _createTargets() {
    return [
      TargetFocus(
        identify: "logVisitKey",
        keyTarget: _logVisitKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildPremiumTutorialCard(
                icon: Icons.check_circle,
                title: "Log Your Visit",
                description:
                    "Been here? Log your visit to keep track of your cafe adventures and build your stats!",
                actionText: "Tap here or Next to continue",
                controller: controller,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "reviewKey",
        keyTarget: _reviewKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildPremiumTutorialCard(
                icon: Icons.rate_review,
                title: "Leave a Review",
                description:
                    "Share your experience with the community. Rate the coffee, vibe, and amenities!",
                actionText: "Tap here to finish the tour",
                controller: controller,
              );
            },
          ),
        ],
      ),
    ];
  }

  Widget _buildPremiumTutorialCard({
    required IconData icon,
    required String title,
    required String description,
    required String actionText,
    TutorialCoachMarkController? controller,
    bool isActionTap = false,
  }) {
    return GestureDetector(
      onTap: () {
        if (!isActionTap && controller != null) {
          controller.next();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1A1A1A).withOpacity(0.95),
              const Color(0xFF111111).withOpacity(0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.redAccent.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.redAccent, Colors.red[800]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (actionText.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.redAccent.withOpacity(0.3), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app,
                        color: Colors.redAccent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        actionText,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    controller?.skip();
                    _markTutorialSeen();
                  },
                  child: const Text('SKIP', style: TextStyle(color: Colors.white54)),
                ),
                if (!isActionTap)
                  ElevatedButton(
                    onPressed: () => controller?.next(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('NEXT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {"""

    content = content.replace(old_class, new_class)
    
    # 3. Replace all instances of `shopId` with `widget.shopId` and `shop` with `widget.shop` inside `build` method
    # Since there are many, we can use regex
    # Wait, we only need to replace them in the first lines of the build method where it checks:
    content = content.replace("if (shopId != null && shopId!.isNotEmpty) {", "if (widget.shopId != null && widget.shopId!.isNotEmpty) {")
    content = content.replace(".doc(shopId)", ".doc(widget.shopId)")
    content = content.replace("return _buildContent(context, shop ?? const <String, dynamic>{});", "return _buildContent(context, widget.shop ?? const <String, dynamic>{});")
    content = content.replace("final String? shopId;", "final String? shopId;") # do nothing
    
    with open(path, 'w') as f:
        f.write(content)

if __name__ == "__main__":
    update_cafe_details()
