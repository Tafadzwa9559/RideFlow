import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/account/account.dart';
import '../features/driver/driver.dart';
import '../features/driver/registration.dart';
import '../features/entry/entry.dart';
import '../features/passenger/home.dart';
import '../shared/models.dart';
import '../shared/widgets.dart';
import 'controller.dart';
import 'theme.dart';

class TriviaApp extends ConsumerStatefulWidget {
  const TriviaApp({super.key});
  @override
  ConsumerState<TriviaApp> createState() => _TriviaAppState();
}

class _TriviaAppState extends ConsumerState<TriviaApp>
    with WidgetsBindingObserver {
  final navigation = GlobalKey<NavigatorState>();
  bool hadSession = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      final app = ref.read(appProvider);
      app.addListener(sessionChanged);
      app.initialize();
    });
  }

  void sessionChanged() {
    final app = ref.read(appProvider);
    if (hadSession && app.session == null) {
      navigation.currentState?.popUntil((r) => r.isFirst);
    }
    hadSession = app.session != null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final app = ref.read(appProvider);
    if (state == AppLifecycleState.resumed) {
      app.resume();
    } else if (state == AppLifecycleState.paused) {
      app.pause();
    }
  }

  @override
  void dispose() {
    ref.read(appProvider).removeListener(sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    return MaterialApp(
      navigatorKey: navigation,
      title: 'Trivia',
      debugShowCheckedModeBanner: false,
      theme: triviaTheme(),
      darkTheme: triviaDarkTheme(),
      themeMode: app.themeMode,
      home: ListenableBuilder(
        listenable: app,
        builder: (_, _) {
          if (!app.ready) {
            return const SplashScreen();
          }
          if (app.initializationFailed) {
            return Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Brand(large: true),
                      ErrorNotice(app),
                      ActionButton(
                        'Retry initialization',
                        app.initialize,
                        busy: app.busy,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          if (!app.onboarded) {
            return Onboarding(app: app);
          }
          if (app.session == null) {
            return AuthScreen(app: app);
          }
          if (app.session!.firstName.isEmpty) {
            return ProfileSetup(app: app);
          }
          return MainShell(key: ValueKey(app.driverMode), app: app);
        },
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.app});
  final AppController app;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final driver = app.driverMode;
    if (driver && app.session?.driverStatus != DriverStatus.approved) {
      return SafeArea(child: DriverRegistration(app: app));
    }
    final pages = <Widget>[
      driver ? DriverHome(app: app) : PassengerHome(app: app),
      driver ? DriverRequests(app: app) : HistoryPage(app: app),
      driver
          ? EarningsPage(app: app)
          : ResourcePage(
              app: app,
              title: 'Notifications',
              resource: 'notifications',
              empty: 'You’re all caught up. Trip updates will appear here.',
            ),
      AccountPage(app: app),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: IndexedStack(index: tab, children: pages),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(
              driver ? Icons.local_taxi_outlined : Icons.receipt_long_outlined,
            ),
            label: driver ? 'Requests' : 'Activity',
          ),
          NavigationDestination(
            icon: Icon(
              driver
                  ? Icons.account_balance_wallet_outlined
                  : Icons.notifications_none,
            ),
            label: driver ? 'Earnings' : 'Notifications',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
