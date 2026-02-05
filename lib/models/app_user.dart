class AppUser {
  final String uid;
  final String email;
  final String role; // 'roommate' or 'house_rep'
  final String? houseId; // Null until they join a house

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.houseId,
  });

  // Convert user data to a Map to store in Firestore
  Map<String, dynamic> toMap() {
    return {'uid': uid, 'email': email, 'role': role, 'houseId': houseId};
  }
}
