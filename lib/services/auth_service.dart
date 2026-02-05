import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Sign Up Function
  Future<void> signUp({
    required String email,
    required String password,
    required String role, // Pass 'roommate' or 'house_rep' here
  }) async {
    try {
      // 1. Create User in Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Create User Document in Firestore
      AppUser newUser = AppUser(
        uid: result.user!.uid,
        email: email,
        role: role,
      );

      // This creates a document with the same ID as the User
      await _db.collection('users').doc(newUser.uid).set(newUser.toMap());
    } catch (e) {
      print('Error signing up: $e');
      rethrow; // Pass error to UI to show alert
    }
  }

  // Sign In Function
  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
