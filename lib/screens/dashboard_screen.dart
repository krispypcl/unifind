import 'package:flutter/material.dart';
import '../main.dart';
import 'login_screen.dart';
import 'views/items_list_view.dart';
import 'views/add_item_view.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  Future<void> _logout(BuildContext context) async {
    await supabase.auth.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // The main content area switches based on sidebar selection
    final Widget currentView = _selectedIndex == 0 
        ? const ItemsListView() 
        : const AddItemView();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perez_Prefinal - Admin Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar Navigation
          Container(
            width: 250,
            color: Colors.blueGrey[50],
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.list),
                  title: const Text('View All Items'),
                  selected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                ListTile(
                  leading: const Icon(Icons.add_circle),
                  title: const Text('Add Item'),
                  selected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
              ],
            ),
          ),
          // Main Content Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: currentView,
            ),
          ),
        ],
      ),
    );
  }
}