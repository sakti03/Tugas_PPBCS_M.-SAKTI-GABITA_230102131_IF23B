import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _petNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _daysController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedPetType = 'Kucing';
  String? _errorMessage;
  bool _isSaving = false;

  Future<void> _submitBooking() async {
    final user = FirebaseAuth.instance.currentUser;
    final petName = _petNameController.text.trim();
    final ownerName = _ownerNameController.text.trim();
    final days = int.tryParse(_daysController.text.trim());
    final notes = _notesController.text.trim();

    if (user == null) return;

    if (petName.isEmpty || ownerName.isEmpty || days == null || days <= 0) {
      setState(() {
        _errorMessage = 'Isi nama hewan, nama pemilik, dan lama hari dengan benar.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _firestore.collection('pet_bookings').add({
        'petName': petName,
        'petType': _selectedPetType,
        'ownerName': ownerName,
        'days': days,
        'notes': notes,
        'createdAt': Timestamp.now(),
        'userId': user.uid,
        'userEmail': user.email,
      });

      _petNameController.clear();
      _ownerNameController.clear();
      _daysController.clear();
      _notesController.clear();
      setState(() {
        _selectedPetType = 'Kucing';
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Gagal menyimpan booking. Silakan coba lagi.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _petNameController.dispose();
    _ownerNameController.dispose();
    _daysController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _deleteBooking(String bookingId) async {
    try {
      await _firestore.collection('pet_bookings').doc(bookingId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking berhasil dihapus.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus booking.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Penitipan Hewan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Halo, ${user?.email ?? 'Pengguna'}!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Text(
              'Formulir Booking Penitipan Hewan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ownerNameController,
              decoration: const InputDecoration(
                labelText: 'Nama Pemilik',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _petNameController,
              decoration: const InputDecoration(
                labelText: 'Nama Hewan',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedPetType,
              decoration: const InputDecoration(
                labelText: 'Jenis Hewan',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Kucing', child: Text('Kucing')),
                DropdownMenuItem(value: 'Anjing', child: Text('Anjing')),
                DropdownMenuItem(value: 'Burung', child: Text('Burung')),
                DropdownMenuItem(value: 'Lainnya', child: Text('Lainnya')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPetType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _daysController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Lama Penitipan (hari)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan tambahan',
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submitBooking,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Simpan Booking'),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Riwayat Booking Anda',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('pet_bookings')
                    .where('userId', isEqualTo: user?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('Belum ada booking.'));
                  }

                  final docs = List.of(snapshot.data!.docs);
                  docs.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aTs = aData['createdAt'] as Timestamp?;
                    final bTs = bData['createdAt'] as Timestamp?;
                    return (bTs?.compareTo(aTs ?? Timestamp.now()) ?? 0);
                  });

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final petName = data['petName'] ?? '';
                      final petType = data['petType'] ?? '';
                      final ownerName = data['ownerName'] ?? '';
                      final days = data['days']?.toString() ?? '';
                      final notes = data['notes'] ?? '';
                      final createdAt = data['createdAt'] as Timestamp?;
                      final createdAtText = createdAt != null
                          ? createdAt.toDate().toString().split('.').first
                          : '';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text('$petName ($petType)'),
                          subtitle: Text('Pemilik: $ownerName\nLama: $days hari${notes.isNotEmpty ? '\nCatatan: $notes' : ''}${createdAtText.isNotEmpty ? '\nTanggal: $createdAtText' : ''}'),
                          isThreeLine: notes.isNotEmpty || createdAtText.isNotEmpty,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteBooking(doc.id),
                            tooltip: 'Hapus booking',
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}