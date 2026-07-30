import re

def fix_home_screen():
    path = 'lib/features/home/home_screen.dart'
    with open(path, 'r') as f:
        content = f.read()

    old_sig = """  Widget _buildPremiumTutorialCard({
    required IconData icon,
    required String title,
    required String description,
    required String actionText,
  }) {
    return Container("""
    
    new_sig = """  Widget _buildPremiumTutorialCard({
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
      child: Container("""

    content = content.replace(old_sig, new_sig)

    old_buttons = """          if (actionText.isNotEmpty) ...[
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
          ]
        ],
      ),
    );
  }"""

    new_buttons = """          if (actionText.isNotEmpty) ...[
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
    ));
  }"""
    content = content.replace(old_buttons, new_buttons)

    with open(path, 'w') as f:
        f.write(content)

def fix_cafe_details():
    path = 'lib/features/cafe/cafe_details_screen.dart'
    with open(path, 'r') as f:
        content = f.read()

    # The issue is that shopId and shop were used inside the build/buildContent methods 
    # but not prefixed with widget. because it was a StatelessWidget previously.
    # Also inside the _buildContent method, the variables like shopId are used directly 
    # but we need to use widget.shopId since we're in State class now.

    # First, let's fix all direct `shopId` usages that were errors
    content = content.replace("child: _BookmarkButton(shopId: shopId)", "child: _BookmarkButton(shopId: widget.shopId)")
    content = content.replace("_buildHeaderRatingWidget(shopId, ratings,", "_buildHeaderRatingWidget(widget.shopId, ratings,")
    content = content.replace("(shopId != null && shopId!.isNotEmpty)", "(widget.shopId != null && widget.shopId!.isNotEmpty)")
    content = content.replace("? _buildReviewsSummaryStream(shopId!)", "? _buildReviewsSummaryStream(widget.shopId!)")
    content = content.replace("? _buildReviewsSectionStream(shopId!)", "? _buildReviewsSectionStream(widget.shopId!)")
    content = content.replace("final sm = shop ?? const <String, dynamic>{};", "final sm = widget.shop ?? const <String, dynamic>{};")
    content = content.replace("'preselectShopId': shopId,", "'preselectShopId': widget.shopId,")
    content = content.replace("shopId: shopId,", "shopId: widget.shopId,")
    content = content.replace("shopId: shopId ?? '',", "shopId: widget.shopId ?? '',")

    with open(path, 'w') as f:
        f.write(content)

if __name__ == "__main__":
    fix_home_screen()
    fix_cafe_details()
