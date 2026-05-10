import 'package:flutter/material.dart';
import 'package:veriframe_app/l10n/generated/app_localizations.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  // Sample notification list
  final List<Map<String, String>> _notifications = [
    {
      "title": "appointmentReminder",
      "message": "appointmentMessage",
      "time": "10 minutes"
    },
    {
      "title": "paymentConfirmation",
      "message": "paymentMessage",
      "time": "1 hour"
    },
    {
      "title": "newDoctorAdded",
      "message": "doctorMessage",
      "time": "3 hours"
    },
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    // Map of localization key to actual localized string
    final Map<String, String> localizedTitles = {
      "appointmentReminder": loc.appointmentReminder,
      "paymentConfirmation": loc.paymentConfirmation,
      "newDoctorAdded": loc.newDoctorAdded,
    };

    final Map<String, String> localizedMessages = {
      "appointmentMessage": loc.appointmentMessage,
      "paymentMessage": loc.paymentMessage,
      "doctorMessage": loc.doctorMessage,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.notifications),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumb Section (Home / Notifications)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Home / Notifications",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
            ),
            // Notification List
            Expanded(
              child: ListView.builder(
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  final titleKey = notification["title"]!;
                  final messageKey = notification["message"]!;
                  final time = notification["time"]!;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.notifications, color: Colors.blue),
                      title: Text(
                        localizedTitles[titleKey] ?? titleKey,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(localizedMessages[messageKey] ?? messageKey),
                      trailing: Text(
                        loc.timeAgo(time),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}



