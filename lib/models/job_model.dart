import 'package:cloud_firestore/cloud_firestore.dart';

class JobApplication {
  final String id;
  final String applicantId;
  final String applicantName;
  final String applicantEmail;
  final String applicantPhone;
  final String resumeUrl;
  final String resumeFileName;
  final String coverLetter;

  /// One of: pending, accepted, approved, rejected, withdrawn.
  final String status;
  final DateTime? appliedAt;
  final String jobId;

  JobApplication({
    required this.id,
    required this.applicantId,
    this.applicantName = '',
    this.applicantEmail = '',
    this.applicantPhone = '',
    this.resumeUrl = '',
    this.resumeFileName = '',
    this.coverLetter = '',
    this.status = 'pending',
    this.appliedAt,
    this.jobId = '',
  });

  factory JobApplication.fromFirestore(Map<String, dynamic> data) {
    return JobApplication(
      id: data['id'] as String? ?? '',
      applicantId: data['applicantId'] as String? ?? '',
      applicantName: data['applicantName'] as String? ?? 'Applicant',
      applicantEmail: data['applicantEmail'] as String? ?? '',
      applicantPhone: data['applicantPhone'] as String? ?? '',
      resumeUrl: data['resumeUrl'] as String? ?? '',
      resumeFileName: data['resumeFileName'] as String? ?? '',
      coverLetter: data['coverLetter'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      appliedAt: Job._parseDate(data['appliedAt']),
      jobId: data['jobId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'applicantId': applicantId,
        'applicantName': applicantName,
        'applicantEmail': applicantEmail,
        'applicantPhone': applicantPhone,
        'resumeUrl': resumeUrl,
        'resumeFileName': resumeFileName,
        'coverLetter': coverLetter,
        'status': status,
        if (appliedAt != null) 'appliedAt': Timestamp.fromDate(appliedAt!),
        if (jobId.isNotEmpty) 'jobId': jobId,
      };
}

class Job {
  final String id;
  final String title;

  /// Part Time / Full Time.
  final String type;
  final String rate;
  final String paymentType;

  /// Legacy documents may store this as `required`.
  final String qualifications;
  final String description;
  final String email;
  final String link;

  /// Legacy alias chain on read: address -> location.
  final String address;
  final DateTime? startDate;
  final DateTime? endDate;

  /// One of: pending, active, closed. Archived jobs use isArchived instead.
  final String status;
  final String shopId;

  /// Legacy alias chain on read: shopName -> cafe -> name.
  final String shopName;
  final String city;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<JobApplication> applications;
  final bool isArchived;
  final bool isPaused;

  Job({
    required this.id,
    this.title = 'Job',
    this.type = 'Unknown',
    this.rate = 'TBD',
    this.paymentType = 'Per Hour',
    this.qualifications = '',
    this.description = '',
    this.email = '',
    this.link = '',
    this.address = '',
    this.startDate,
    this.endDate,
    this.status = 'active',
    this.shopId = '',
    this.shopName = '',
    this.city = 'Davao City',
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.applications = const [],
    this.isArchived = false,
    this.isPaused = false,
  });

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value);
      } catch (_) {}
    }
    return null;
  }

  factory Job.fromFirestore(Map<String, dynamic> data, String id) {
    return Job(
      id: id,
      title: data['title'] as String? ?? 'Job',
      type: data['type'] as String? ?? 'Unknown',
      rate: data['rate'] as String? ?? 'TBD',
      paymentType: data['paymentType'] as String? ?? 'Per Hour',
      qualifications:
          data['qualifications'] as String? ?? data['required'] as String? ?? '',
      description: data['description'] as String? ?? '',
      email: data['email'] as String? ?? '',
      link: data['link'] as String? ?? '',
      address: data['address'] as String? ??
          data['location'] as String? ??
          '',
      startDate: _parseDate(data['startDate']),
      endDate: _parseDate(data['endDate']),
      status: data['status'] as String? ?? 'active',
      shopId: data['shopId'] as String? ?? '',
      shopName: data['shopName'] as String? ??
          data['cafe'] as String? ??
          data['name'] as String? ??
          '',
      city: data['city'] as String? ?? 'Davao City',
      createdBy: data['createdBy'] as String?,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      applications: ((data['applications'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(JobApplication.fromFirestore)
          .toList(),
      isArchived: data['isArchived'] as bool? ?? false,
      isPaused: data['isPaused'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'type': type,
        'rate': rate,
        'paymentType': paymentType,
        'qualifications': qualifications,
        'description': description,
        'email': email,
        'link': link,
        'address': address,
        if (startDate != null) 'startDate': Timestamp.fromDate(startDate!),
        if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
        'status': status,
        'shopId': shopId,
        'shopName': shopName,
        'city': city,
        if (createdBy != null) 'createdBy': createdBy,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
        'applications': applications.map((a) => a.toFirestore()).toList(),
        'isArchived': isArchived,
        'isPaused': isPaused,
      };
}
