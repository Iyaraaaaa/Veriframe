import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key});

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen> with TickerProviderStateMixin {
  final PageController controller = PageController();
  int selectPage = 0;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<Map<String, String>> pageArr = [
    {
      "img": "assets/images/on_board_1.avif",
      "title": "VeriFrame",
      "subtitle": "A healthier nation that contributes to its economic, social, mental, and spiritual development.",
      "accent": "0xFF2196F3", // Blue
    },
    {
      "img": "assets/images/on_board_2.jpg",
      "title": "සෞඛ්‍ය අමාත්‍යාංශය",
      "subtitle": "ආර්ථික, සමාජ, මානසික සහ ආත්මික සංවර්ධනයට දායක වන සෞඛ්‍යයෙන් පිරි නව ජාතියක්.",
      "accent": "0xFF4CAF50", // Green
    },
    {
      "img": "assets/images/on_board_3.jpg",
      "title": "சுகாதார அமைச்சகம்",
      "subtitle": "அனைத்து துறைகளிலும் முன்னேற்றம் அடைந்த ஆரோக்கியமான நாடு.",
      "accent": "0xFFFF9800", // Orange
    },
  ];

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _startAnimations();
  }

  void _startAnimations() {
    _fadeController.forward();
    _slideController.forward();
  }

  void _onPageChanged(int page) {
    setState(() {
      selectPage = page;
    });

    // Restart animations for new page
    _fadeController.reset();
    _slideController.reset();
    Future.delayed(const Duration(milliseconds: 100), () {
      _startAnimations();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    controller.dispose();
    super.dispose();
  }

  Color get currentAccentColor {
    final colorString = pageArr[selectPage]["accent"]!;
    return Color(int.parse(colorString));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F4C75),
              const Color(0xFF3282B8),
              currentAccentColor.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Background pattern
              Positioned.fill(
                child: CustomPaint(
                  painter: BackgroundPatternPainter(currentAccentColor),
                ),
              ),

              // Main PageView
              PageView.builder(
                controller: controller,
                itemCount: pageArr.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final obj = pageArr[index];
                  return _buildPage(obj, size);
                },
              ),

              // Bottom navigation controls
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomControls(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(Map<String, String> obj, Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // Image container with enhanced styling
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                height: size.height * 0.45,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: currentAccentColor.withOpacity(0.2),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        obj["img"]!,
                        fit: BoxFit.cover,
                      ),
                      // Gradient overlay for better text contrast
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.1),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const Spacer(),

          // Content section
          SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
                .animate(CurvedAnimation(
              parent: _slideController,
              curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
            )),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
                parent: _fadeController,
                curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
              )),
              child: Column(
                children: [
                  // Title
                  Text(
                    obj["title"]!,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(
                          blurRadius: 10,
                          color: Colors.black.withOpacity(0.3),
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // Subtitle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      obj["subtitle"]!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Page indicators
                  _buildPageIndicators(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 120), // Space for bottom controls
        ],
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageArr.length, (i) {
        final isActive = selectPage == i;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: isActive ? 32 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(6),
            boxShadow: isActive ? [
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
        );
      }),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.1),
            Colors.black.withOpacity(0.2),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Skip button
          _buildControlButton(
            text: "Skip",
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
            isPrimary: false,
          ),

          // Next/Get Started button
          _buildControlButton(
            text: selectPage == pageArr.length - 1 ? "Get Started" : "Next",
            onPressed: () {
              if (selectPage == pageArr.length - 1) {
                Navigator.pushReplacementNamed(context, '/login');
              } else {
                controller.nextPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutCubic,
                );
              }
            },
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required String text,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isPrimary ? [
          BoxShadow(
            color: currentAccentColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: Material(
        color: isPrimary ? currentAccentColor : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (isPrimary && selectPage != pageArr.length - 1) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BackgroundPatternPainter extends CustomPainter {
  final Color accentColor;

  BackgroundPatternPainter(this.accentColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Draw subtle geometric patterns
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(
          size.width * (0.1 + i * 0.2),
          size.height * (0.1 + i * 0.15),
        ),
        30 + i * 10,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}



