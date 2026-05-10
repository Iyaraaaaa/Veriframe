import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart'; // Add url_launcher for phone call functionality
import 'package:veriframe_app/l10n/generated/app_localizations.dart';

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!; // Get current localization strings

    // Set dynamic color for the AppBar based on the theme
    Color appBarColor = isDark ? Colors.black : Colors.blue;
    Color textColor = isDark ? Colors.white : Colors.black;
    Color iconColor = isDark ? Colors.white : Colors.blue;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      appBar: AppBar(
        title: Text(loc.contactUs), // Use localized string
        centerTitle: true,
        backgroundColor: appBarColor, // Dynamic background color based on theme
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumb
            Text(
              loc.homeContactUs, // Use localized breadcrumb
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 20),

            // Title Section
            Text(
              loc.contactDetails, // Localized
              style: TextStyle(
                color: Colors.blue,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              loc.generalInquiries, // Localized
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor, // Dynamically adjust color
              ),
            ),
            const SizedBox(height: 12),
            Text(
              loc.contactText, // Localized
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 20),

            // Address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc.address, // Localized
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor, // Dynamically adjust color
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Phone
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.phone, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _makePhoneCall(),
                    child: Text(
                      "(94) 112 694033     (94) 112 693493\n"
                      "(94) 112 675011     (94) 112 675280\n"
                      "(94) 112 675449     (94) 112 669192",
                      style: TextStyle(fontSize: 15, height: 1.6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Email
            Row(
              children: [
                Icon(Icons.email, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "info(at)health.gov.lk",
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Map Title
            Text(
              loc.locationOnMap, // Localized string
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor, // Dynamically adjust color
              ),
            ),
            const SizedBox(height: 10),

            // Flutter Map (shortened map box)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 200, // Adjusted height
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(6.9271, 79.8612),
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.vitality_health',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(6.9271, 79.8612),
                          width: 20,
                          height: 20,
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _makePhoneCall() async {
    final url = Uri(scheme: 'tel', path: '0112678044'); // Change this to desired number
    if (await canLaunch(url.toString())) {
      await launch(url.toString());
    } else {
      print('Could not launch phone dialer');
    }
  }
}




