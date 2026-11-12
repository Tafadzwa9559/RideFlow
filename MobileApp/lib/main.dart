
import 'package:flutter/material.dart';

void main() {
  runApp(const RideFlowApp());
}

class RideFlowApp extends StatelessWidget {
  const RideFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RideFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF16A34A),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const RideFlowHome(),
    );
  }
}

class RideFlowHome extends StatefulWidget {
  const RideFlowHome({super.key});

  @override
  State<RideFlowHome> createState() => _RideFlowHomeState();
}

class _RideFlowHomeState extends State<RideFlowHome> {
  final pickupController = TextEditingController();
  final destinationController = TextEditingController();

  int selectedTab = 0;
  String selectedRide = 'Standard';

  @override
  void dispose() {
    pickupController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  void showRidePreview() {
    if (pickupController.text.trim().isEmpty ||
        destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your pickup and destination.'),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ride Preview'),
        content: Text(
          'Pickup: ${pickupController.text}\n'
          'Destination: ${destinationController.text}\n'
          'Ride type: $selectedRide\n\n'
          'Live booking will be available after backend integration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget rideOption(String title, IconData icon, String subtitle) {
    final selected = selectedRide == title;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => selectedRide = title),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFEAF8EF)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFE2E8F0),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 29,
                color: selected
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF475569),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget homeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 25,
                backgroundColor: Color(0xFFE2F5E9),
                child: Icon(
                  Icons.person_outline,
                  color: Color(0xFF15803D),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to RideFlow',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      'Where to today?',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => selectedTab = 1),
                icon: const Icon(Icons.history),
              ),
            ],
          ),
          const SizedBox(height: 30),

          const Text(
            'Your journey, your choice.',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Book a comfortable ride in a few simple steps.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 25),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Book your ride',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: pickupController,
                  decoration: InputDecoration(
                    labelText: 'Pickup location',
                    hintText: 'Enter your pickup point',
                    prefixIcon: const Icon(
                      Icons.radio_button_checked,
                      color: Color(0xFF16A34A),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: destinationController,
                  decoration: InputDecoration(
                    labelText: 'Destination',
                    hintText: 'Where are you going?',
                    prefixIcon: const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFFEF4444),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 27),
          const Text(
            'Choose your ride',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),

          Row(
            children: [
              rideOption('Standard', Icons.directions_car, 'Everyday'),
              const SizedBox(width: 9),
              rideOption('Comfort', Icons.local_taxi, 'Extra comfort'),
              const SizedBox(width: 9),
              rideOption('XL', Icons.airport_shuttle, 'More space'),
            ],
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: showRidePreview,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Find a Ride',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Safe journeys start here.',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['RideFlow', 'My Trips', 'Wallet', 'Profile'];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        title: Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Ride',
                style: TextStyle(color: Color(0xFF0F172A)),
              ),
              const TextSpan(
                text: 'Flow',
                style: TextStyle(color: Color(0xFF16A34A)),
              ),
            ],
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
        centerTitle: false,
      ),
      body: selectedTab == 0
          ? homeContent()
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.construction_outlined,
                    size: 50,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    titles[selectedTab],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('This section is coming soon.'),
                ],
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() => selectedTab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
