import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_si.dart';
import 'app_localizations_ta.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('si'),
    Locale('ta')
  ];

  /// No description provided for @healthStaffAffirmation.
  ///
  /// In en, this message translates to:
  /// **'Health Staff Affirmation'**
  String get healthStaffAffirmation;

  /// No description provided for @staffDetails.
  ///
  /// In en, this message translates to:
  /// **'Staff Details'**
  String get staffDetails;

  /// No description provided for @incidentId.
  ///
  /// In en, this message translates to:
  /// **'Incident ID'**
  String get incidentId;

  /// No description provided for @reporterName.
  ///
  /// In en, this message translates to:
  /// **'Reporter Name'**
  String get reporterName;

  /// No description provided for @badgeNumber.
  ///
  /// In en, this message translates to:
  /// **'Badge Number'**
  String get badgeNumber;

  /// No description provided for @threatLevel.
  ///
  /// In en, this message translates to:
  /// **'Designation'**
  String get threatLevel;

  /// No description provided for @targetPlatform.
  ///
  /// In en, this message translates to:
  /// **'Target Platform'**
  String get targetPlatform;

  /// No description provided for @datesSection.
  ///
  /// In en, this message translates to:
  /// **'Dates Section'**
  String get datesSection;

  /// No description provided for @incidentDate.
  ///
  /// In en, this message translates to:
  /// **'Incident Date'**
  String get incidentDate;

  /// No description provided for @dateDetected.
  ///
  /// In en, this message translates to:
  /// **'Date Detected'**
  String get dateDetected;

  /// No description provided for @assignedInvestigator.
  ///
  /// In en, this message translates to:
  /// **'Assigned Investigator'**
  String get assignedInvestigator;

  /// No description provided for @evidenceReference.
  ///
  /// In en, this message translates to:
  /// **'Evidence Reference'**
  String get evidenceReference;

  /// No description provided for @deficiencyTracking.
  ///
  /// In en, this message translates to:
  /// **'Deficiency Tracking'**
  String get deficiencyTracking;

  /// No description provided for @escalationDate.
  ///
  /// In en, this message translates to:
  /// **'Escalation Date'**
  String get escalationDate;

  /// No description provided for @resolutionDate.
  ///
  /// In en, this message translates to:
  /// **'Resolution Date'**
  String get resolutionDate;

  /// No description provided for @approvalSection.
  ///
  /// In en, this message translates to:
  /// **'Approval Section'**
  String get approvalSection;

  /// No description provided for @lawEnforcementDate.
  ///
  /// In en, this message translates to:
  /// **'Chief Secretary Sent Date'**
  String get lawEnforcementDate;

  /// No description provided for @reviewDate.
  ///
  /// In en, this message translates to:
  /// **'Review Date'**
  String get reviewDate;

  /// No description provided for @closureDate.
  ///
  /// In en, this message translates to:
  /// **'Closure Date'**
  String get closureDate;

  /// No description provided for @submitForm.
  ///
  /// In en, this message translates to:
  /// **'Submit Form'**
  String get submitForm;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get requiredField;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Please select a date.'**
  String get selectDate;

  /// No description provided for @pleaseSelect.
  ///
  /// In en, this message translates to:
  /// **'Please select an option.'**
  String get pleaseSelect;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @formSubmittedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Form Submitted Successfully!'**
  String get formSubmittedSuccess;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @generalInquiries.
  ///
  /// In en, this message translates to:
  /// **'General Inquiries'**
  String get generalInquiries;

  /// No description provided for @contactDetails.
  ///
  /// In en, this message translates to:
  /// **'Contact Details'**
  String get contactDetails;

  /// No description provided for @contactText.
  ///
  /// In en, this message translates to:
  /// **'Thanks for your interest in reaching the Ministry of Health, Sri Lanka. Below is the contact information for frequently requested departments. Please use the website search feature located below to find an email address or phone number.'**
  String get contactText;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Suwasiripaya, No. 385, Rev. Baddegama Wimalawansa Thero Mawatha, Colombo 10, Sri Lanka.'**
  String get address;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'(94) 112 694033     (94) 112 693493\n(94) 112 675011     (94) 112 675280\n(94) 112 675449     (94) 112 669192'**
  String get phone;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'info(at)health.gov.lk'**
  String get email;

  /// No description provided for @locationOnMap.
  ///
  /// In en, this message translates to:
  /// **'Location on Map'**
  String get locationOnMap;

  /// No description provided for @appointmentReminder.
  ///
  /// In en, this message translates to:
  /// **'Appointment Reminder'**
  String get appointmentReminder;

  /// No description provided for @appointmentMessage.
  ///
  /// In en, this message translates to:
  /// **'You have an appointment with Dr. Smith at 10:30 AM.'**
  String get appointmentMessage;

  /// No description provided for @paymentConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Payment Confirmation'**
  String get paymentConfirmation;

  /// No description provided for @paymentMessage.
  ///
  /// In en, this message translates to:
  /// **'Your payment for consultation has been received.'**
  String get paymentMessage;

  /// No description provided for @newDoctorAdded.
  ///
  /// In en, this message translates to:
  /// **'New Doctor Added'**
  String get newDoctorAdded;

  /// No description provided for @doctorMessage.
  ///
  /// In en, this message translates to:
  /// **'Dr. Jane Doe has been added to your favorites.'**
  String get doctorMessage;

  /// No description provided for @timeAgo.
  ///
  /// In en, this message translates to:
  /// **'{time} ago'**
  String timeAgo(Object time);

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @introduction.
  ///
  /// In en, this message translates to:
  /// **'1. Introduction'**
  String get introduction;

  /// No description provided for @introductionContent.
  ///
  /// In en, this message translates to:
  /// **'This is the introduction of the privacy policy.\n\nWe value your privacy and explain how your data is collected and used.'**
  String get introductionContent;

  /// No description provided for @personalData.
  ///
  /// In en, this message translates to:
  /// **'2. Personal Data We Collect'**
  String get personalData;

  /// No description provided for @personalDataContent.
  ///
  /// In en, this message translates to:
  /// **'Details about the data we collect, including your name, email, and usage data.\n\nThis data helps us improve our services and provide a better user experience.'**
  String get personalDataContent;

  /// No description provided for @cookiePolicy.
  ///
  /// In en, this message translates to:
  /// **'3. Cookie Policy'**
  String get cookiePolicy;

  /// No description provided for @cookiePolicyContent.
  ///
  /// In en, this message translates to:
  /// **'What are cookies?\n\nA cookie is a small file stored on your device. We use cookies to enhance user experience but we respect your privacy and provide an option to disable them.'**
  String get cookiePolicyContent;

  /// No description provided for @homeContactUs.
  ///
  /// In en, this message translates to:
  /// **'Home / Contact Us'**
  String get homeContactUs;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @affirmation.
  ///
  /// In en, this message translates to:
  /// **'Affirmation'**
  String get affirmation;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @ministryName.
  ///
  /// In en, this message translates to:
  /// **'Ministry of Health'**
  String get ministryName;

  /// No description provided for @services.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get services;

  /// No description provided for @news.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get news;

  /// No description provided for @emergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emergency;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @emergencyCalled.
  ///
  /// In en, this message translates to:
  /// **'Emergency call made'**
  String get emergencyCalled;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected item'**
  String get selected;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get changeLanguage;

  /// No description provided for @switchToLightMode.
  ///
  /// In en, this message translates to:
  /// **'Switch to Light Mode'**
  String get switchToLightMode;

  /// No description provided for @switchToDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Switch to Dark Mode'**
  String get switchToDarkMode;

  /// No description provided for @ourVision.
  ///
  /// In en, this message translates to:
  /// **'Our Vision'**
  String get ourVision;

  /// No description provided for @ourMission.
  ///
  /// In en, this message translates to:
  /// **'Our Mission'**
  String get ourMission;

  /// No description provided for @missionText.
  ///
  /// In en, this message translates to:
  /// **'To contribute to the social and economic development of Sri Lanka by achieving the highest attainable health levels through preventive, curative and rehabilitative services of high quality, available and accessible to people of Sri Lanka.'**
  String get missionText;

  /// No description provided for @readMore.
  ///
  /// In en, this message translates to:
  /// **'READ MORE'**
  String get readMore;

  /// No description provided for @ministryLeadership.
  ///
  /// In en, this message translates to:
  /// **'VeriFrame Features'**
  String get ministryLeadership;

  /// No description provided for @minister.
  ///
  /// In en, this message translates to:
  /// **'Minister of Health and Mass Media'**
  String get minister;

  /// No description provided for @deputyMinister.
  ///
  /// In en, this message translates to:
  /// **'Deputy Minister of Health and Mass Media'**
  String get deputyMinister;

  /// No description provided for @secretary.
  ///
  /// In en, this message translates to:
  /// **'Secretary / Ministry of Health and Mass Media'**
  String get secretary;

  /// No description provided for @directorGeneral.
  ///
  /// In en, this message translates to:
  /// **'Director General of Forensic Services'**
  String get directorGeneral;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @sinhala.
  ///
  /// In en, this message translates to:
  /// **'Sinhala'**
  String get sinhala;

  /// No description provided for @tamil.
  ///
  /// In en, this message translates to:
  /// **'Tamil'**
  String get tamil;

  /// No description provided for @welcomeTo.
  ///
  /// In en, this message translates to:
  /// **'Welcome To'**
  String get welcomeTo;

  /// No description provided for @ministryOfHealth.
  ///
  /// In en, this message translates to:
  /// **'Ministry of Health Sri Lanka'**
  String get ministryOfHealth;

  /// No description provided for @visionText.
  ///
  /// In en, this message translates to:
  /// **'We pledge to keep people healthy, to offer high-quality care when it is required, and to safeguard the healthcare system for future generations.'**
  String get visionText;

  /// No description provided for @preHistoricMedicine.
  ///
  /// In en, this message translates to:
  /// **'Pre-Historic Medicine in Ceylon'**
  String get preHistoricMedicine;

  /// No description provided for @medicineUnderSriLankanKings.
  ///
  /// In en, this message translates to:
  /// **'Medicine under Sri Lankan kings'**
  String get medicineUnderSriLankanKings;

  /// No description provided for @aboutUs.
  ///
  /// In en, this message translates to:
  /// **'About Us'**
  String get aboutUs;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @searchBySerialNumber.
  ///
  /// In en, this message translates to:
  /// **'Search by Incident ID'**
  String get searchBySerialNumber;

  /// No description provided for @enterSerialNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter Incident ID'**
  String get enterSerialNumber;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No Results Found'**
  String get noResultsFound;

  /// No description provided for @enterNICNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter Badge Number'**
  String get enterNICNumber;

  /// No description provided for @publicHealth.
  ///
  /// In en, this message translates to:
  /// **'Threat Assessment'**
  String get publicHealth;

  /// No description provided for @hospitalBaseCare.
  ///
  /// In en, this message translates to:
  /// **'Explainable AI'**
  String get hospitalBaseCare;

  /// No description provided for @yourHealthWellBeing.
  ///
  /// In en, this message translates to:
  /// **'Law Enforcement Ready'**
  String get yourHealthWellBeing;

  /// No description provided for @welcomeToHealthMinistry.
  ///
  /// In en, this message translates to:
  /// **'Welcome to VeriFrame'**
  String get welcomeToHealthMinistry;

  /// No description provided for @getYourInformation.
  ///
  /// In en, this message translates to:
  /// **'Get Your Information Here'**
  String get getYourInformation;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @uploadCSV.
  ///
  /// In en, this message translates to:
  /// **'Upload CSV'**
  String get uploadCSV;

  /// No description provided for @pleaseCheckNIC.
  ///
  /// In en, this message translates to:
  /// **'Please check the NIC number and try again.'**
  String get pleaseCheckNIC;

  /// Names of the VeriFrame Features team members
  ///
  /// In en, this message translates to:
  /// **'Minister: AI Engine\nDeputy Minister: Deep Learning Model\nSecretary: Forensic Analysis\nDirector General: Automated Reporting'**
  String get leadershipTeam;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'si', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'si':
      return AppLocalizationsSi();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}



