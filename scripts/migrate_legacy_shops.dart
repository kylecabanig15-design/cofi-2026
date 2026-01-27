import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../lib/firebase_options.dart';

/// Migration script to add approvalStatus to legacy shops
/// 
/// USAGE:
///   dart run scripts/migrate_legacy_shops.dart
/// 
/// SAFETY:
///   - Runs in read-only mode first (dryRun: true)
///   - Shows what would change
///   - Set dryRun: false to apply changes

Future<void> main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  const dryRun = true; // Set to false to actually apply changes
  
  print('🔍 Scanning for legacy shops...\n');
  
  final firestore = FirebaseFirestore.instance;
  final shopsCollection = firestore.collection('shops');
  
  // Find all shops
  final allShops = await shopsCollection.get();
  
  int legacyCount = 0;
  int alreadyMigrated = 0;
  
  final batch = firestore.batch();
  
  for (final doc in allShops.docs) {
    final data = doc.data();
    final hasApprovalStatus = data.containsKey('approvalStatus');
    final hasSubmissionType = data.containsKey('submissionType');
    
    if (!hasApprovalStatus || !hasSubmissionType) {
      legacyCount++;
      
      print('📋 Legacy Shop: ${data['name'] ?? 'Unnamed'}');
      print('   ID: ${doc.id}');
      print('   Missing: ${!hasApprovalStatus ? 'approvalStatus ' : ''}${!hasSubmissionType ? 'submissionType' : ''}');
      
      // Determine migration values
      final ownerId = data['ownerId'];
      final hasOwner = ownerId != null && ownerId.toString().trim().isNotEmpty;
      
      final migrationData = <String, dynamic>{};
      
      if (!hasApprovalStatus) {
        // Business shops with owner = already claimed, mark approved
        // Community shops without owner = pending approval
        migrationData['approvalStatus'] = hasOwner ? 'approved' : 'pending_approval';
      }
      
      if (!hasSubmissionType) {
        // If has ownerId = business account created it
        // Otherwise = community submission
        migrationData['submissionType'] = hasOwner ? 'business' : 'community';
      }
      
      // ✅ Mark business shops as verified and already claimed
      if (hasOwner && !data.containsKey('isVerified')) {
        migrationData['isVerified'] = true;
        print('   ✅ Marking as verified business (already claimed)');
      }
      
      print('   Will set: $migrationData\n');
      
      if (!dryRun) {
        batch.update(doc.reference, migrationData);
      }
    } else {
      alreadyMigrated++;
    }
  }
  
  print('\n📊 Migration Summary:');
  print('   Total shops: ${allShops.docs.length}');
  print('   Legacy shops: $legacyCount');
  print('   Already migrated: $alreadyMigrated');
  
  if (dryRun) {
    print('\n⚠️  DRY RUN MODE - No changes were made');
    print('   Set dryRun = false to apply changes');
  } else {
    print('\n✅ Applying changes...');
    await batch.commit();
    print('✅ Migration complete!');
  }
}
