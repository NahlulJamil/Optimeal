import 'package:cloud_firestore/cloud_firestore.dart';

/// Whether [error] means Firestore could not reach the network.
///
/// Used to turn a failed write into the same message the disabled buttons show
/// (PRD §7.5) instead of a generic "try again".
bool isOfflineError(Object error) =>
    error is FirebaseException &&
    (error.code == 'unavailable' || error.code == 'deadline-exceeded');
