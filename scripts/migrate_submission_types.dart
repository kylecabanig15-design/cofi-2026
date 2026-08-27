import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// One-time migration script to add submissionType field to existing shops
/// 
/// This script:
/// 1. Fetches all shops from Firestore
/// 2. For each shop without a submissionType field:
///    - Checks if the shop has an ownerId
///    - Looks up the owner's accountType
///    - Sets submissionType to 'business' if accountType is 'business', else 'community'
/// 
/// Run this ONCE with: dart run scripts/migrate_submission_types.dart

void main() async {
  print('🚀 Starting submissionType migration...\n');
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  final firestore = FirebaseFirestore.instance;
  
  // Fetch all shops
  final shopsSnapshot = await firestore.collection('shops').get();
  print('📊 Found ${shopsSnapshot.docs.length} shops to process\n');
  
  int updated = 0;
  int skipped = 0;
  int errors = 0;
  
  for (final shopDoc in shopsSnapshot.docs) {
    final data = shopDoc.data();
    final shopId = shopDoc.id;
    final shopName = data['name'] ?? 'Unknown';
    
    // Skip if submissionType already exists
    if (data.containsKey('submissionType')) {
      print('⏭️  Skipping "$shopName" - already has submissionType: ${data['submissionType']}');
      skipped++;
      continue;
    }
    
    try {
      String submissionType = 'community'; // Default
      
      // Check if shop has an owner
      final ownerId = data['ownerId'] as String?;
      final posterId = data['posterId'] as String?;
      final userId = ownerId ?? posterId;
      
      if (userId != null) {
        // Look up the user's accountType
        final userDoc = await firestore.collection('users').doc(userId).get();
        
        if (userDoc.exists) {
          final userData = userDoc.data();
          final accountType = userData?['accountType'] as String? ?? 'user';
          
          if (accountType == 'business') {
            submissionType = 'business';
            print('✅ Setting "$shopName" to BUSINESS (owner: $userId, accountType: $accountType)');
          } else {
            print('ℹ️  Setting "$shopName" to COMMUNITY (owner: $userId, accountType: $accountType)');
          }
        } else {
          print('⚠️  User $userId not found, defaulting "$shopName" to COMMUNITY');
        }
      } else {
        print('ℹ️  No owner found for "$shopName", defaulting to COMMUNITY');
      }
      
      // Update the shop document
      await firestore.collection('shops').doc(shopId).update({
        'submissionType': submissionType,
      });
      
      updated++;
      
    } catch (e) {
      print('❌ Error processing "$shopName": $e');
      errors++;
    }
  }
  
  print('\n${'=' * 60}');
  print('🎉 Migration Complete!');
  print('=' * 60);
  print('✅ Updated: $updated shops');
  print('⏭️  Skipped: $skipped shops (already had submissionType)');
  print('❌ Errors: $errors shops');
  print('=' * 60);
}
