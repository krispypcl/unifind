import 'package:flutter/material.dart';
import '../../main.dart';

class ItemsListView extends StatelessWidget {
  const ItemsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Database: Items', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Expanded(
          // StreamBuilder listens for real-time changes
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase.from('items').stream(primaryKey: ['id']),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final items = snapshot.data!;

              if (items.isEmpty) {
                return const Center(child: Text('No items found in the database.'));
              }

              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  // Using your enums to color-code UI
                  final bool isLost = item['type'] == 'lost';
                  
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        isLost ? Icons.search : Icons.check_circle,
                        color: isLost ? Colors.red : Colors.green,
                      ),
                      title: Text(item['title'] ?? 'No Title'),
                      subtitle: Text('${item['location'] ?? 'Unknown location'} • Status: ${item['status']}'),
                      trailing: Text(
                        (item['type'] as String).toUpperCase(),
                        style: TextStyle(
                          color: isLost ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}