import 'package:flutter/material.dart';
import 'package:veriframe_app/l10n/generated/app_localizations.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Get current theme mode (dark or light)
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Fetch localized strings using AppLocalizations
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.aboutUs), // Use localized string here
        backgroundColor: Colors.blue, // Same color as Notifications page
      ),
      // Background color changes depending on the theme (light or dark)
      backgroundColor: isDarkMode ? Colors.black87 : Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Image (ab.jpg)
            Stack(
              children: [
                Image.asset(
                  'assets/images/ab1.jpg',
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                ),
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Home / About Us",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
            ),

            // Welcome Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text Section
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.welcomeTo, // Localized string
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          loc.ministryOfHealth, // Localized string
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          loc.visionText, // Localized string for vision text
                          style: TextStyle(fontSize: 15, height: 1.6),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Logo Section
                  Expanded(
                    flex: 1,
                    child: Image.asset(
                      'assets/images/ab2.png',
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Pre-Historic Medicine Section
            Container(
              width: double.infinity,
              color: const Color(0xFFF9F7F1),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/ab3.png',
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.preHistoricMedicine, // Localized string for Pre-Historic Medicine section
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3C2F1F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    loc.medicineUnderSriLankanKings, // Localized string for "Medicine under Sri Lankan kings"
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}



