class StudentModel {
  final String id;

  final String serial;

  final String name;

  final String fatherName;

  final String motherName;

  final String phone;

  final String fatherJob;

  final String address;

  final String schoolGrade;

  final String birthDate;

  final String studentType;

  final String supervisorId;

  final String supervisorName;

  final String cycleId;

  final String cycleName;

  final String startMemorization;

  final double memorizedPages;

  final String imageUrl;

  final bool archived;

  final String createdAt;

  StudentModel({
    required this.id,
    required this.serial,
    required this.name,
    required this.fatherName,
    required this.motherName,
    required this.phone,
    required this.fatherJob,
    required this.address,
    required this.schoolGrade,
    required this.birthDate,
    required this.studentType,
    required this.supervisorId,
    required this.supervisorName,
    required this.cycleId,
    required this.cycleName,
    required this.startMemorization,
    required this.memorizedPages,
    required this.imageUrl,
    required this.archived,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'serial': serial,
      'name': name,
      'fatherName': fatherName,
      'motherName': motherName,
      'phone': phone,
      'fatherJob': fatherJob,
      'address': address,
      'schoolGrade': schoolGrade,
      'birthDate': birthDate,
      'studentType': studentType,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'cycleId': cycleId,
      'cycleName': cycleName,
      'startMemorization': startMemorization,
      'memorizedPages': memorizedPages,
      'imageUrl': imageUrl,
      'archived': archived,
      'createdAt': createdAt,
    };
  }

  factory StudentModel.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return StudentModel(
      id: id,
      serial: map['serial'] ?? '',
      name: map['name'] ?? '',
      fatherName: map['fatherName'] ?? '',
      motherName: map['motherName'] ?? '',
      phone: map['phone'] ?? '',
      fatherJob: map['fatherJob'] ?? '',
      address: map['address'] ?? '',
      schoolGrade: map['schoolGrade'] ?? '',
      birthDate: map['birthDate'] ?? '',
      studentType: map['studentType'] ?? '',
      supervisorId: map['supervisorId'] ?? '',
      supervisorName: map['supervisorName'] ?? '',
      cycleId: map['cycleId'] ?? '',
      cycleName: map['cycleName'] ?? '',
      startMemorization:
          map['startMemorization'] ?? '',
      memorizedPages:
          (map['memorizedPages'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      archived: map['archived'] ?? false,
      createdAt: map['createdAt'] ?? '',
    );
  }
}