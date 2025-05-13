class Budget {
  final String id;
  final String name;
  final double budget;
  final String description;
  final String status;
  final String dateSubmitted;
  final String? submittedBy;
  final String? submittedByEmail;
  final String? dateApproved;
  final String? dateDenied;
  final String? denialReason;
  final String? revisionRequested;
  final String? revisionNotes;
  final String? dateArchived;
  final String? companyId;

  Budget({
    required this.id,
    required this.name,
    required this.budget,
    required this.description,
    required this.status,
    required this.dateSubmitted,
    this.submittedBy,
    this.submittedByEmail,
    this.dateApproved,
    this.dateDenied,
    this.denialReason,
    this.revisionRequested,
    this.revisionNotes,
    this.dateArchived,
    this.companyId,
  });

  // Convert a Budget object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'budget': budget,
      'description': description,
      'status': status,
      'dateSubmitted': dateSubmitted,
      'submittedBy': submittedBy,
      'submittedByEmail': submittedByEmail,
      'dateApproved': dateApproved,
      'dateDenied': dateDenied,
      'denialReason': denialReason,
      'revisionRequested': revisionRequested,
      'revisionNotes': revisionNotes,
      'dateArchived': dateArchived,
      'companyId': companyId,
    };
  }

  // Create a Budget object from a Map
  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      budget:
          map['budget'] is int
              ? (map['budget'] as int).toDouble()
              : (map['budget'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] ?? '',
      status: map['status'] ?? '',
      dateSubmitted: map['dateSubmitted'] ?? '',
      submittedBy: map['submittedBy'],
      submittedByEmail: map['submittedByEmail'],
      dateApproved: map['dateApproved'],
      dateDenied: map['dateDenied'],
      denialReason: map['denialReason'],
      revisionRequested: map['revisionRequested'],
      revisionNotes: map['revisionNotes'],
      dateArchived: map['dateArchived'],
      companyId: map['companyId'],
    );
  }
}
