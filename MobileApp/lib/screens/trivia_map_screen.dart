import 'package:flutter/material.dart';

import '../core/map_view.dart';

class TriviaMapScreen extends StatelessWidget {
  const TriviaMapScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trivia Map')),
    body: const TriviaMap(),
  );
}
