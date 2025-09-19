import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_service.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to submit a complaint.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await FirebaseFirestore.instance.collection('complaints').add({
        'uid': user.uid,
        'subject': _subjectCtrl.text.trim(),
        'details': _detailsCtrl.text.trim(),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _subjectCtrl.clear();
      _detailsCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complaint submitted successfully.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit complaint: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Provider.of<AuthService>(context).user;
    return Scaffold(
      appBar: AppBar(title: const Text('Complaints')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Submit a Complaint', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _subjectCtrl,
                      decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder(), prefixIcon: Icon(Icons.subject)),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Enter a subject' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _detailsCtrl,
                      decoration: const InputDecoration(labelText: 'Details', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description)),
                      minLines: 3,
                      maxLines: 5,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Enter details' : null,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: const FaIcon(FontAwesomeIcons.paperPlane, color: Colors.white),
                      label: _submitting ? const Text('Submitting...') : const Text('Submit'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('My Complaints', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (user == null)
            const Text('Sign in to view your complaints.')
          else
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('complaints')
                  .where('uid', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) return const Text('No complaints yet.');
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final subject = data['subject'] as String? ?? '';
                    final status = data['status'] as String? ?? 'open';
                    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          status == 'open' ? Icons.mark_unread_chat_alt : Icons.check_circle,
                          color: status == 'open' ? Colors.orange : Colors.green,
                        ),
                        title: Text(subject),
                        subtitle: Text(createdAt != null ? '${createdAt.toLocal()}'.split(' ')[0] : ''),
                        trailing: Chip(label: Text(status)),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
