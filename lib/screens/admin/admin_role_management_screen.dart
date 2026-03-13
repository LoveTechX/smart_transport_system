import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminRoleManagementScreen extends StatefulWidget {
  const AdminRoleManagementScreen({super.key});

  @override
  State<AdminRoleManagementScreen> createState() =>
      _AdminRoleManagementScreenState();
}

class _AdminRoleManagementScreenState extends State<AdminRoleManagementScreen> {
  static const List<String> _roles = <String>[
    'passenger',
    'driver',
    'conductor',
    'admin',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Map<String, String> _updatingRoleByUid = <String, String>{};

  Stream<QuerySnapshot<Map<String, dynamic>>> get _usersStream {
    return _firestore.collection('users').orderBy('email').snapshots();
  }

  Future<void> _changeUserRole({
    required String docId,
    required String uid,
    required String newRole,
  }) async {
    final currentUser = _auth.currentUser;

    setState(() {
      _updatingRoleByUid[uid] = newRole;
    });

    try {
      final callable = _functions.httpsCallable('setUserRole');
      await callable.call(<String, dynamic>{
        'uid': uid,
        'role': newRole,
      });

      // Keep Firestore role in sync if rules allow direct write.
      try {
        await _firestore.collection('users').doc(docId).set(
          <String, dynamic>{'role': newRole},
          SetOptions(merge: true),
        );
      } catch (_) {
        // Ignore sync failures here because callable update already succeeded.
      }

      if (currentUser != null && currentUser.uid == uid) {
        await currentUser.getIdTokenResult(true);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role updated to "$newRole" for $uid')),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to change role. Please try again.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unexpected error while changing role.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingRoleByUid.remove(uid);
        });
      }
    }
  }

  String _normalizedRole(Object? roleValue) {
    final role = roleValue?.toString() ?? 'passenger';
    return _roles.contains(role) ? role : 'passenger';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Role Management'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _usersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load users: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          if (docs.isEmpty) {
            return const Center(
                child: Text('No users found in "users" collection.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final uid = (data['uid'] as String?)?.trim().isNotEmpty == true
                  ? (data['uid'] as String)
                  : doc.id;
              final email =
                  (data['email'] as String?)?.trim().isNotEmpty == true
                      ? (data['email'] as String)
                      : 'No email';
              final currentRole = _normalizedRole(data['role']);

              final pendingRole = _updatingRoleByUid[uid];
              final selectedRole = pendingRole ?? currentRole;
              final isUpdating = pendingRole != null;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text('UID: $uid',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedRole,
                              decoration: const InputDecoration(
                                labelText: 'Role',
                              ),
                              items: _roles
                                  .map(
                                    (role) => DropdownMenuItem<String>(
                                      value: role,
                                      child: Text(role),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: isUpdating
                                  ? null
                                  : (newRole) {
                                      if (newRole == null ||
                                          newRole == currentRole) {
                                        return;
                                      }
                                      _changeUserRole(
                                        docId: doc.id,
                                        uid: uid,
                                        newRole: newRole,
                                      );
                                    },
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (isUpdating)
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
