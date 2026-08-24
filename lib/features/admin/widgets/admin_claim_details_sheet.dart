import 'package:flutter/material.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/features/admin/widgets/admin_badges.dart';

void showAdminClaimDetailsSheet(
  BuildContext context, {
  required String claimId,
  required Map<String, dynamic> data,
  required Future<void> Function(String shopId) onRejectShop,
  required Future<void> Function(String shopId) onApproveShop,
  required Future<void> Function(String claimId, {String? shopId}) onRejectClaim,
  required Future<void> Function(String claimId, String? shopId, String? claimantId)
      onApproveClaim,
}) {
  final shopName = data['shopName'] as String? ?? 'Unknown Shop';
  final claimantEmail = data['claimantEmail'] as String? ?? 'No email';
  final legalName = data['businessLegalName'] as String? ?? 'Not provided';
  final role = data['applicantRole'] as String? ?? 'Not provided';
  final docRef =
      data['verificationDocReference'] as String? ?? 'Not provided';
  final permitUrl = data['permitImageUrl'] as String?;
  final idUrl = data['idImageUrl'] as String?;

  final attestation = data['legalAttestation'] as bool? ?? false;
  final termsAccepted = data['legalTermsAccepted'] as bool? ?? false;
  final dataConsent = data['dataProcessingConsent'] as bool? ?? false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextWidget(
                                  text: 'OWNERSHIP REVIEW',
                                  fontSize: 10,
                                  color: primary,
                                  isBold: true,
                                ),
                                const SizedBox(height: 4),
                                TextWidget(
                                  text: shopName,
                                  fontSize: 26,
                                  color: Colors.white,
                                  isBold: true,
                                ),
                              ],
                            ),
                          ),
                          buildAdminStatusIndicator(data['status'] ?? 'pending',
                              data['status'] == 'approved'),
                        ],
                      ),
                      const SizedBox(height: 40),

                      _buildReviewSection('Claimant Identity', [
                        _buildDetailRow('Professional Email', claimantEmail),
                        _buildDetailRow('Legal Entity Name', legalName),
                        _buildDetailRow('Applicant Position', role),
                      ]),

                      const SizedBox(height: 32),
                      _buildReviewSection('Evidence & Docs', [
                        _buildDetailRow('Document Reference', docRef),
                        if (permitUrl != null) ...[
                          const SizedBox(height: 12),
                          TextWidget(
                              text: 'Business Permit / BIR COR',
                              fontSize: 12,
                              color: Colors.grey),
                          const SizedBox(height: 8),
                          _buildImagePreview(context, permitUrl, 'Business Permit'),
                        ],
                        if (idUrl != null) ...[
                          const SizedBox(height: 20),
                          TextWidget(
                              text: 'Representative ID',
                              fontSize: 12,
                              color: Colors.grey),
                          const SizedBox(height: 8),
                          _buildImagePreview(context, idUrl, 'ID Card'),
                        ],
                        if (permitUrl == null && idUrl == null)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text('No visual documents provided.',
                                style:
                                    TextStyle(color: Colors.amber, fontSize: 13)),
                          ),
                      ]),

                      const SizedBox(height: 32),
                      _buildReviewSection('Legal Compliance', [
                        _buildLegalTag(
                            'Authorized Representative', attestation),
                        _buildLegalTag(
                            'Terms of Service Accepted', termsAccepted),
                        _buildLegalTag(
                            'Data Processing Consent', dataConsent),
                      ]),

                      const SizedBox(height: 120), // Space for buttons
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Bottom Actions
          if (data['status'] == 'pending' ||
              data['isDirectSubmission'] == true)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0),
                      const Color(0xFF1A1A1A)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.2],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (data['isDirectSubmission'] == true) {
                            onRejectShop(data['shopId']);
                          } else {
                            onRejectClaim(claimId, shopId: data['shopId']);
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                            data['isDirectSubmission'] == true
                                ? 'Reject Shop'
                                : 'Reject Claim',
                            style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (data['isDirectSubmission'] == true) {
                            onApproveShop(data['shopId']);
                          } else {
                            onApproveClaim(
                                claimId, data['shopId'], data['claimantId']);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(
                            data['isDirectSubmission'] == true
                                ? 'Approve Shop'
                                : 'Confirm Approval',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

Widget _buildReviewSection(String title, List<Widget> children) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          TextWidget(
            text: title.toUpperCase(),
            fontSize: 10,
            color: Colors.white24,
            isBold: true,
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider(color: Colors.white10)),
        ],
      ),
      const SizedBox(height: 20),
      ...children,
    ],
  );
}

Widget _buildDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(text: label, fontSize: 11, color: Colors.white38),
        const SizedBox(height: 4),
        TextWidget(text: value, fontSize: 15, color: Colors.white),
      ],
    ),
  );
}

Widget _buildLegalTag(String label, bool value) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: (value ? Colors.green : Colors.redAccent).withOpacity(0.05),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
          color: (value ? Colors.green : Colors.redAccent).withOpacity(0.15)),
    ),
    child: Row(
      children: [
        Icon(
          value ? Icons.verified_rounded : Icons.warning_amber_rounded,
          color: value ? Colors.green : Colors.redAccent,
          size: 16,
        ),
        const SizedBox(width: 10),
        Expanded(
            child:
                TextWidget(text: label, fontSize: 13, color: Colors.white70)),
      ],
    ),
  );
}

Widget _buildImagePreview(BuildContext context, String url, String title) {
  return GestureDetector(
    onTap: () {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              InteractiveViewer(
                child: Center(
                  child: Image.network(
                    url,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: IconButton(
                  icon:
                      const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
    },
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: 200,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.black54,
                child: const Center(
                  child: Text('Tap to zoom',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
