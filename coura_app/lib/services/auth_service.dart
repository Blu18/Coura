import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
      if (googleUser == null) return; 

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.idToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        _saveUserToFirestore(user);
      }
    } catch (e) {
      // print("Error en signInWithGoogle: $e");
    }
  }

  Future<void> _saveUserToFirestore(User user) async {
    final userDocRef = _db.collection('users').doc(user.uid);
    await userDocRef.set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
  
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}