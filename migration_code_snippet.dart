// Add this method to AdminDashboardScreen

Future<void> _runLegacyShopMigration() async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text('Migrate Legacy Shops', style: TextStyle(color: Colors.white)),
      content: const Text(
        'This will add approvalStatus and submissionType fields to all shops missing them.\\n\\n'
        'Shops with ownerId will be marked as approved business shops.\\n'
        'Shops without ownerId will be marked as pending community shops.\\n\\n'
        'This action is safe and can be run multiple times.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: primary),
          child: const Text('Run Migration'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    final firestore = FirebaseFirestore.instance;
    final allShops = await firestore.collection('shops').get();
    
    int migratedCount = 0;
    int skippedCount = 0;
    final batch = firestore.batch();
    
    for (final doc in allShops.docs) {
      final data = doc.data();
      final hasApprovalStatus = data.containsKey('approvalStatus');
      final hasSubmissionType = data.containsKey('submissionType');
      
      if (!hasApprovalStatus || !hasSubmissionType) {
        final ownerId = data['ownerId'];
        final hasOwner = ownerId != null && ownerId.toString().trim().isNotEmpty;
        
        final migrationData = <String, dynamic>{};
        
        if (!hasApprovalStatus) {
          migrationData['approvalStatus'] = hasOwner ? 'approved' : 'pending_approval';
        }
        
        if (!hasSubmissionType) {
          migrationData['submissionType'] = hasOwner ? 'business' : 'community';
        }
        
        if (hasOwner && !data.containsKey('isVerified')) {
          migrationData['isVerified'] = true;
        }
        
        batch.update(doc.reference, migrationData);
        migratedCount++;
      } else {
        skippedCount++;
      }
    }
    
    await batch.commit();
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 12),
              Text('Migration Complete', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Text(
            'Total shops: ${allShops.docs.length}\\n'
            'Migrated: $migratedCount\\n'
            'Already up-to-date: $skippedCount',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Migration failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Add button to admin dashboard UI:
// ElevatedButton(
//   onPressed: _runLegacyShopMigration,
//   child: Text('Migrate Legacy Shops'),
// )
