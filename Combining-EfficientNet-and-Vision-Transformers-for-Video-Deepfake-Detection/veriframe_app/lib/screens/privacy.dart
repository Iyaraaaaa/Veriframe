import 'package:flutter/material.dart';
import 'package:veriframe_app/l10n/generated/app_localizations.dart';

class PrivacyPage extends StatefulWidget {
  @override
  _PrivacyPolicyPageState createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPage> {
  final List<bool> _isExpanded = [false, false, false];

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;

    // AppBar background color change based on the theme
    Color appBarColor = isDarkMode ? Colors.grey[850]! : Colors.blue;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor, // Dynamic background color based on theme
        elevation: 0,
        centerTitle: true,
        title: Text(
          loc.privacyPolicy, // Localized Title
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () {
            Navigator.pop(context); // Return to previous screen
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Breadcrumb Section (Home / Privacy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Home / Privacy",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
              ),
              // Privacy Policy Expansion Tiles
              _buildExpansionTile(0, loc.introduction, loc.introductionContent),
              _buildExpansionTile(1, loc.personalData, loc.personalDataContent),
              _buildExpansionTile(2, loc.cookiePolicy, loc.cookiePolicyContent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpansionTile(int index, String title, String content) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 4,
      color: isDarkMode ? Colors.grey[800] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        trailing: Icon(
          _isExpanded[index] ? Icons.remove_circle_outline : Icons.add_circle_outline,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(12.0),
            child: Text(
              content,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded[index] = expanded;
          });
        },
      ),
    );
  }
}



