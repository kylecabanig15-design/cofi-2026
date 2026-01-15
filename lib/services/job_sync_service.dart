import 'package:cloud_firestore/cloud_firestore.dart';

class JobSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Syncs job status from pendingJobs to the shop's jobs collection
  /// This ensures both collections are in sync when admin updates the status
  static Future<void> syncJobStatus(String jobId) async {
    try {
      // Get the job from pendingJobs
      final pendingJobDoc =
          await _firestore.collection('pendingJobs').doc(jobId).get();

      if (!pendingJobDoc.exists) {
        print('Job not found in pendingJobs: $jobId');
        return;
      }

      final pendingJobData = pendingJobDoc.data() as Map<String, dynamic>;
      final shopId = pendingJobData['shopId'] as String?;
      final status = pendingJobData['status'] as String?;

      if (shopId == null || status == null) {
        print('Missing shopId or status in pendingJob');
        return;
      }

      // Update the status in the shop's jobs collection
      await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('jobs')
          .doc(jobId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Successfully synced job $jobId status to $status');
    } catch (e) {
      print('Error syncing job status: $e');
      rethrow;
    }
  }

  /// Syncs all fields from pendingJobs to the shop's jobs collection
  /// Use this when you want a complete sync of all data
  static Future<void> syncJobAll(String jobId) async {
    try {
      // Get the job from pendingJobs
      final pendingJobDoc =
          await _firestore.collection('pendingJobs').doc(jobId).get();

      if (!pendingJobDoc.exists) {
        print('Job not found in pendingJobs: $jobId');
        return;
      }

      final pendingJobData = pendingJobDoc.data() as Map<String, dynamic>;
      final shopId = pendingJobData['shopId'] as String?;

      if (shopId == null) {
        print('Missing shopId in pendingJob');
        return;
      }

      // Prepare data for shop's jobs collection (exclude doc management fields)
      final shopJobData = {...pendingJobData};
      shopJobData.remove('jobId'); // Remove duplicate ID field
      shopJobData['updatedAt'] = FieldValue.serverTimestamp();

      // Update the shop's jobs collection
      await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('jobs')
          .doc(jobId)
          .set(shopJobData, SetOptions(merge: true));

      print('Successfully synced all data for job $jobId');
    } catch (e) {
      print('Error syncing job data: $e');
      rethrow;
    }
  }
}
