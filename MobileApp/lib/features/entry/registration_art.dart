part of 'entry.dart';

class _RegistrationBrand extends StatelessWidget {
  const _RegistrationBrand();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.asset(
            'assets/trivia-icon.png',
            width: 52,
            height: 52,
            cacheWidth: 156,
            semanticLabel: 'Trivia',
          ),
        ),
        const SizedBox(height: 7),
        const Text('Your Journey. Your Choice.', textAlign: TextAlign.center),
      ],
    ),
  );
}

class _RegistrationHero extends StatelessWidget {
  const _RegistrationHero();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: (constraints.maxWidth * .41).clamp(100.0, 175.0),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(36),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(36),
            bottomLeft: Radius.circular(18),
          ),
          child: ColoredBox(
            color: darkGreen,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 2,
                    child: Image.asset(
                      'assets/images/registration/harare-640.webp',
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -.35),
                    ),
                  ),
                  const SizedBox(
                    width: 3,
                    child: ColoredBox(color: triviaOrange),
                  ),
                  Expanded(
                    flex: 5,
                    child: Image.asset(
                      'assets/images/registration/city-car-640.webp',
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _RegistrationFooter extends StatelessWidget {
  const _RegistrationFooter();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const ExcludeSemantics(
        child: SizedBox(
          width: double.infinity,
          height: 25,
          child: CustomPaint(painter: _SkylinePainter()),
        ),
      ),
      const SizedBox(height: 5),
      Text(
        'Developed by MOrdec Solutions (Private) Limited',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class _SkylinePainter extends CustomPainter {
  const _SkylinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 25);
    final skyline = Paint()..color = emerald.withValues(alpha: .18);
    for (final (x, width, top) in [
      (62.0, 4.0, 14.0),
      (67.0, 4.0, 9.0),
      (72.0, 5.0, 12.0),
      (78.0, 4.0, 3.0),
      (83.0, 5.0, 8.0),
      (89.0, 5.0, 13.0),
    ]) {
      canvas.drawRect(Rect.fromLTRB(x, top, x + width, 24), skyline);
    }
    final curve = Path()
      ..moveTo(0, 24)
      ..cubicTo(30, 25, 60, 10, 100, 23)
      ..lineTo(100, 25)
      ..lineTo(0, 25)
      ..close();
    canvas.drawPath(curve, Paint()..color = darkGreen);
    canvas.drawPath(
      Path()
        ..moveTo(68, 17)
        ..quadraticBezierTo(84, 14, 99, 20),
      Paint()
        ..color = triviaOrange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkylinePainter oldDelegate) => false;
}
