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
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ta'),
  ];

  /// No description provided for @healthStaffAffirmation.
  ///
  /// In en, this message translates to:
  /// **'Deepfake Analysis'**
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
  /// **'Thanks for your interest in reaching the VeriFrame System, Sri Lanka. Below is the contact information for frequently requested departments. Please use the website search feature located below to find an email address or phone number.'**
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

  /// No description provided for @reportTab.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportTab;

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
  /// **'VeriFrame System'**
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
  /// **'Ministry Leadership'**
  String get ministryLeadership;

  /// No description provided for @minister.
  ///
  /// In en, this message translates to:
  /// **'Chief Investigator'**
  String get minister;

  /// No description provided for @deputyMinister.
  ///
  /// In en, this message translates to:
  /// **'Deputy Chief Investigator'**
  String get deputyMinister;

  /// No description provided for @secretary.
  ///
  /// In en, this message translates to:
  /// **'Cybersecurity Expert'**
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
  /// **'VeriFrame Cybercrime System'**
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

  /// Names of the ministry leadership team members
  ///
  /// In en, this message translates to:
  /// **'Minister: Dr. Nalinda Jayatissa\nDeputy Minister: Dr. Hansaka Vijemuni\nSecretary: Dr. Anil Jayasighe\nDirector General: Dr. Asela Gunawaradena'**
  String get leadershipTeam;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @analyzeVideo.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get analyzeVideo;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @forensicPlatform.
  ///
  /// In en, this message translates to:
  /// **'VeriFrame Forensic Detection Platform'**
  String get forensicPlatform;

  /// No description provided for @aiVideoAuth.
  ///
  /// In en, this message translates to:
  /// **'AI-Powered Video Authenticity Verification'**
  String get aiVideoAuth;

  /// No description provided for @heroDesc1.
  ///
  /// In en, this message translates to:
  /// **'Detect deepfakes, manipulated videos, and synthetic media using advanced AI analysis and explainable forensic reasoning.'**
  String get heroDesc1;

  /// No description provided for @heroDesc2.
  ///
  /// In en, this message translates to:
  /// **'VeriFrame analyzes uploaded videos, video links, and live streams using EfficientViT and CrossEfficientViT models to determine whether media is authentic or manipulated.\n\nThe platform generates confidence scores, forensic evidence, and detailed reports to support digital trust and cybercrime investigations.'**
  String get heroDesc2;

  /// No description provided for @whatIsVeriFrame.
  ///
  /// In en, this message translates to:
  /// **'What is VeriFrame?'**
  String get whatIsVeriFrame;

  /// No description provided for @whatIsDesc.
  ///
  /// In en, this message translates to:
  /// **'VeriFrame helps journalists, investigators, organizations, students, and the public identify manipulated videos and potential deepfakes.\n\nThe system performs AI-powered forensic analysis and provides transparent explanations of why content is considered authentic or suspicious.'**
  String get whatIsDesc;

  /// No description provided for @features.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get features;

  /// No description provided for @featVideoVerification.
  ///
  /// In en, this message translates to:
  /// **'Video Verification'**
  String get featVideoVerification;

  /// No description provided for @featVideoVerificationDesc.
  ///
  /// In en, this message translates to:
  /// **'Analyze uploaded videos using AI.'**
  String get featVideoVerificationDesc;

  /// No description provided for @featLinkVerification.
  ///
  /// In en, this message translates to:
  /// **'Link Verification'**
  String get featLinkVerification;

  /// No description provided for @featLinkVerificationDesc.
  ///
  /// In en, this message translates to:
  /// **'Analyze videos directly from a URL.'**
  String get featLinkVerificationDesc;

  /// No description provided for @featLiveStream.
  ///
  /// In en, this message translates to:
  /// **'Live Stream Monitoring'**
  String get featLiveStream;

  /// No description provided for @featLiveStreamDesc.
  ///
  /// In en, this message translates to:
  /// **'Detect manipulation in streaming content.'**
  String get featLiveStreamDesc;

  /// No description provided for @featAiReasoning.
  ///
  /// In en, this message translates to:
  /// **'AI Reasoning'**
  String get featAiReasoning;

  /// No description provided for @featAiReasoningDesc.
  ///
  /// In en, this message translates to:
  /// **'Understand why a video was flagged.'**
  String get featAiReasoningDesc;

  /// No description provided for @featForensicReports.
  ///
  /// In en, this message translates to:
  /// **'Forensic Reports'**
  String get featForensicReports;

  /// No description provided for @featForensicReportsDesc.
  ///
  /// In en, this message translates to:
  /// **'Generate downloadable investigation reports.'**
  String get featForensicReportsDesc;

  /// No description provided for @featAuthorityReporting.
  ///
  /// In en, this message translates to:
  /// **'Authority Reporting'**
  String get featAuthorityReporting;

  /// No description provided for @featAuthorityReportingDesc.
  ///
  /// In en, this message translates to:
  /// **'Submit high-risk cases for review.'**
  String get featAuthorityReportingDesc;

  /// No description provided for @howItWorks.
  ///
  /// In en, this message translates to:
  /// **'How It Works'**
  String get howItWorks;

  /// No description provided for @stepUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload / Link / Live Stream'**
  String get stepUploadTitle;

  /// No description provided for @stepUploadDesc.
  ///
  /// In en, this message translates to:
  /// **'Submit media for analysis via supported methods.'**
  String get stepUploadDesc;

  /// No description provided for @stepFaceDetectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Face Detection'**
  String get stepFaceDetectionTitle;

  /// No description provided for @stepFaceDetectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Identify and crop facial regions across frames.'**
  String get stepFaceDetectionDesc;

  /// No description provided for @stepAiAnalysisTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Analysis'**
  String get stepAiAnalysisTitle;

  /// No description provided for @stepAiAnalysisDesc.
  ///
  /// In en, this message translates to:
  /// **'Process frames using EfficientViT & CrossEfficientViT.'**
  String get stepAiAnalysisDesc;

  /// No description provided for @stepReasoningEngineTitle.
  ///
  /// In en, this message translates to:
  /// **'Reasoning Engine'**
  String get stepReasoningEngineTitle;

  /// No description provided for @stepReasoningEngineDesc.
  ///
  /// In en, this message translates to:
  /// **'Generate explainable insights on anomalies.'**
  String get stepReasoningEngineDesc;

  /// No description provided for @stepAuthenticityScoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Authenticity Score'**
  String get stepAuthenticityScoreTitle;

  /// No description provided for @stepAuthenticityScoreDesc.
  ///
  /// In en, this message translates to:
  /// **'Calculate final confidence and risk level.'**
  String get stepAuthenticityScoreDesc;

  /// No description provided for @stepForensicReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Forensic Report'**
  String get stepForensicReportTitle;

  /// No description provided for @stepForensicReportDesc.
  ///
  /// In en, this message translates to:
  /// **'Compile detailed findings into a downloadable report.'**
  String get stepForensicReportDesc;

  /// No description provided for @verifyMedia.
  ///
  /// In en, this message translates to:
  /// **'Verify Media'**
  String get verifyMedia;

  /// No description provided for @verifyMediaDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose a verification method to analyze a video for authenticity and potential manipulation.'**
  String get verifyMediaDesc;

  /// No description provided for @uploadVideo.
  ///
  /// In en, this message translates to:
  /// **'Upload Video'**
  String get uploadVideo;

  /// No description provided for @uploadVideoDesc.
  ///
  /// In en, this message translates to:
  /// **'Upload a video file from your device for AI analysis.'**
  String get uploadVideoDesc;

  /// No description provided for @supportedFormats.
  ///
  /// In en, this message translates to:
  /// **'Supported: MP4, MOV, AVI, MKV'**
  String get supportedFormats;

  /// No description provided for @selectVideo.
  ///
  /// In en, this message translates to:
  /// **'Select Video'**
  String get selectVideo;

  /// No description provided for @analyzeVideoLink.
  ///
  /// In en, this message translates to:
  /// **'Analyze Video Link'**
  String get analyzeVideoLink;

  /// No description provided for @analyzeVideoLinkDesc.
  ///
  /// In en, this message translates to:
  /// **'Paste a public video URL and let VeriFrame analyze its authenticity.'**
  String get analyzeVideoLinkDesc;

  /// No description provided for @enterVideoUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter video URL...'**
  String get enterVideoUrl;

  /// No description provided for @urlExamples.
  ///
  /// In en, this message translates to:
  /// **'Examples: YouTube, Facebook, TikTok, Instagram, X'**
  String get urlExamples;

  /// No description provided for @analyzeLink.
  ///
  /// In en, this message translates to:
  /// **'Analyze Link'**
  String get analyzeLink;

  /// No description provided for @analyzeLiveStream.
  ///
  /// In en, this message translates to:
  /// **'Analyze Live Stream'**
  String get analyzeLiveStream;

  /// No description provided for @analyzeLiveStreamDesc.
  ///
  /// In en, this message translates to:
  /// **'Monitor and analyze live streaming content in real time.'**
  String get analyzeLiveStreamDesc;

  /// No description provided for @enterStreamUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter stream URL...'**
  String get enterStreamUrl;

  /// No description provided for @streamExamples.
  ///
  /// In en, this message translates to:
  /// **'Supported: RTMP, HLS, YouTube Live, Facebook Live'**
  String get streamExamples;

  /// No description provided for @analyzeStream.
  ///
  /// In en, this message translates to:
  /// **'Analyze Stream'**
  String get analyzeStream;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN'**
  String get signInTitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'LOGIN'**
  String get loginButton;

  /// No description provided for @googleSignIn.
  ///
  /// In en, this message translates to:
  /// **'GOOGLE SIGN IN'**
  String get googleSignIn;

  /// No description provided for @needAccount.
  ///
  /// In en, this message translates to:
  /// **'Need an account?'**
  String get needAccount;

  /// No description provided for @signUpLink.
  ///
  /// In en, this message translates to:
  /// **'SIGN UP'**
  String get signUpLink;

  /// No description provided for @signUpTitle.
  ///
  /// In en, this message translates to:
  /// **'SIGN UP'**
  String get signUpTitle;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createAccount;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @sendVerification.
  ///
  /// In en, this message translates to:
  /// **'SEND VERIFICATION'**
  String get sendVerification;

  /// No description provided for @completeRegistration.
  ///
  /// In en, this message translates to:
  /// **'COMPLETE REGISTRATION'**
  String get completeRegistration;

  /// No description provided for @clickVerificationLink.
  ///
  /// In en, this message translates to:
  /// **'Click the verification link sent to your email'**
  String get clickVerificationLink;

  /// No description provided for @emailVerifiedMsg.
  ///
  /// In en, this message translates to:
  /// **'Email verified! You can now complete registration'**
  String get emailVerifiedMsg;

  /// No description provided for @alreadyAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyAccount;

  /// No description provided for @signInLink.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN'**
  String get signInLink;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'FORGOT PASSWORD'**
  String get forgotPasswordTitle;

  /// No description provided for @enterEmailReset.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to reset password'**
  String get enterEmailReset;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'SEND RESET LINK'**
  String get sendResetLink;

  /// No description provided for @rememberedPassword.
  ///
  /// In en, this message translates to:
  /// **'Remembered your password?'**
  String get rememberedPassword;

  /// No description provided for @loginAction.
  ///
  /// In en, this message translates to:
  /// **'LOGIN'**
  String get loginAction;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @settingsSection.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsSection;

  /// No description provided for @aboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutSection;

  /// No description provided for @veriFrameVersion.
  ///
  /// In en, this message translates to:
  /// **'VeriFrame v1.0'**
  String get veriFrameVersion;

  /// No description provided for @appDescription.
  ///
  /// In en, this message translates to:
  /// **'Forensic deepfake detection using EfficientViT and CrossEfficientViT'**
  String get appDescription;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Forensic deepfake detection platform powered by EfficientViT and CrossEfficientViT models. Designed for law enforcement and digital forensic investigators.'**
  String get aboutDescription;

  /// No description provided for @aiSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Analysis Settings'**
  String get aiSettingsTitle;

  /// No description provided for @modelSelection.
  ///
  /// In en, this message translates to:
  /// **'Model Selection'**
  String get modelSelection;

  /// No description provided for @modelSelectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose which neural network model runs inference for deepfake verification. The active model name will be sent with every analysis request.'**
  String get modelSelectionDesc;

  /// No description provided for @efficientViTName.
  ///
  /// In en, this message translates to:
  /// **'EfficientViT'**
  String get efficientViTName;

  /// No description provided for @efficientViTDesc.
  ///
  /// In en, this message translates to:
  /// **'EfficientNet B0 CNN Backbone combined with a Vision Transformer (ViT) head. Recommended for fast, lightweight inference with high boundary precision.'**
  String get efficientViTDesc;

  /// No description provided for @crossEfficientViTName.
  ///
  /// In en, this message translates to:
  /// **'CrossEfficientViT'**
  String get crossEfficientViTName;

  /// No description provided for @crossEfficientViTDesc.
  ///
  /// In en, this message translates to:
  /// **'Multi-scale cross-attention architecture that analyzes features at multiple granularities concurrently. Highly robust against compression and warping anomalies.'**
  String get crossEfficientViTDesc;

  /// No description provided for @activeModelSet.
  ///
  /// In en, this message translates to:
  /// **'Active model set to {model}'**
  String activeModelSet(Object model);

  /// No description provided for @pleaseEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get pleaseEnterName;

  /// No description provided for @nameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get nameTooShort;

  /// No description provided for @pleaseEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterEmail;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get invalidEmail;

  /// No description provided for @pleaseEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterPassword;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShort;

  /// No description provided for @pleaseConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get pleaseConfirmPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @registrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration Failed'**
  String get registrationFailed;

  /// No description provided for @emailAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'Email already in use. Please use a different email.'**
  String get emailAlreadyInUse;

  /// No description provided for @weakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak. Please choose a stronger password.'**
  String get weakPassword;

  /// No description provided for @invalidEmailFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format.'**
  String get invalidEmailFormat;

  /// No description provided for @accountsNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'Email/password accounts are not enabled.'**
  String get accountsNotEnabled;

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get unexpectedError;

  /// No description provided for @pleaseVerifyEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Please verify your email first.'**
  String get pleaseVerifyEmailFirst;

  /// No description provided for @userNotFoundTryAgain.
  ///
  /// In en, this message translates to:
  /// **'User not found. Please try again.'**
  String get userNotFoundTryAgain;

  /// No description provided for @failedCompleteRegistration.
  ///
  /// In en, this message translates to:
  /// **'Failed to complete registration. Please try again.'**
  String get failedCompleteRegistration;

  /// No description provided for @registrationCompleted.
  ///
  /// In en, this message translates to:
  /// **'Registration completed successfully!'**
  String get registrationCompleted;

  /// No description provided for @verificationEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent! Please check your inbox.'**
  String get verificationEmailSent;

  /// No description provided for @emailVerifiedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Email verified successfully!'**
  String get emailVerifiedSuccess;

  /// No description provided for @imageSizeError.
  ///
  /// In en, this message translates to:
  /// **'Image size should be less than 5MB'**
  String get imageSizeError;

  /// No description provided for @failedPickImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick image: {error}'**
  String failedPickImage(Object error);

  /// No description provided for @passwordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent!'**
  String get passwordResetSent;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyTitle;

  /// No description provided for @privacyLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated: June 2025'**
  String get privacyLastUpdated;

  /// No description provided for @privacyIntro.
  ///
  /// In en, this message translates to:
  /// **'VeriFrame is committed to protecting your privacy. This policy explains how we collect, use, and safeguard your information when you use our deepfake detection platform.'**
  String get privacyIntro;

  /// No description provided for @privacyS1Title.
  ///
  /// In en, this message translates to:
  /// **'Information We Collect'**
  String get privacyS1Title;

  /// No description provided for @privacyS1Body.
  ///
  /// In en, this message translates to:
  /// **'We collect information you provide directly, including video files uploaded for analysis, account credentials, and usage data. Uploaded videos are processed in real-time and are not stored permanently on our servers without your explicit consent.'**
  String get privacyS1Body;

  /// No description provided for @privacyS1B1.
  ///
  /// In en, this message translates to:
  /// **'Video content submitted for detection'**
  String get privacyS1B1;

  /// No description provided for @privacyS1B2.
  ///
  /// In en, this message translates to:
  /// **'Device identifiers and app usage metrics'**
  String get privacyS1B2;

  /// No description provided for @privacyS1B3.
  ///
  /// In en, this message translates to:
  /// **'Authentication data (Firebase Auth)'**
  String get privacyS1B3;

  /// No description provided for @privacyS1B4.
  ///
  /// In en, this message translates to:
  /// **'Analysis results and confidence logs'**
  String get privacyS1B4;

  /// No description provided for @privacyS2Title.
  ///
  /// In en, this message translates to:
  /// **'How We Use Your Data'**
  String get privacyS2Title;

  /// No description provided for @privacyS2Body.
  ///
  /// In en, this message translates to:
  /// **'Your data is used exclusively to provide deepfake detection services, improve our AI models, and enhance system reliability. We do not sell your personal data to third parties.'**
  String get privacyS2Body;

  /// No description provided for @privacyS2B1.
  ///
  /// In en, this message translates to:
  /// **'Real-time video analysis via our Agent Engine'**
  String get privacyS2B1;

  /// No description provided for @privacyS2B2.
  ///
  /// In en, this message translates to:
  /// **'Improving detection accuracy over time'**
  String get privacyS2B2;

  /// No description provided for @privacyS2B3.
  ///
  /// In en, this message translates to:
  /// **'Security monitoring and fraud prevention'**
  String get privacyS2B3;

  /// No description provided for @privacyS2B4.
  ///
  /// In en, this message translates to:
  /// **'Generating anonymized research insights'**
  String get privacyS2B4;

  /// No description provided for @privacyS3Title.
  ///
  /// In en, this message translates to:
  /// **'Data Storage & Security'**
  String get privacyS3Title;

  /// No description provided for @privacyS3Body.
  ///
  /// In en, this message translates to:
  /// **'All data is encrypted in transit and at rest. We use industry-standard security protocols including JWT authentication, Firebase security rules, and AWS S3 encryption to protect your information.'**
  String get privacyS3Body;

  /// No description provided for @privacyS3B1.
  ///
  /// In en, this message translates to:
  /// **'AES-256 encryption for stored data'**
  String get privacyS3B1;

  /// No description provided for @privacyS3B2.
  ///
  /// In en, this message translates to:
  /// **'TLS 1.3 for all data transmission'**
  String get privacyS3B2;

  /// No description provided for @privacyS3B3.
  ///
  /// In en, this message translates to:
  /// **'JWT-based session management'**
  String get privacyS3B3;

  /// No description provided for @privacyS3B4.
  ///
  /// In en, this message translates to:
  /// **'Regular security audits and penetration testing'**
  String get privacyS3B4;

  /// No description provided for @privacyS4Title.
  ///
  /// In en, this message translates to:
  /// **'Third-Party Services'**
  String get privacyS4Title;

  /// No description provided for @privacyS4Body.
  ///
  /// In en, this message translates to:
  /// **'VeriFrame integrates with trusted third-party services to deliver its functionality. Each service operates under its own privacy terms.'**
  String get privacyS4Body;

  /// No description provided for @privacyS4B1.
  ///
  /// In en, this message translates to:
  /// **'Firebase (Google) — Auth & database'**
  String get privacyS4B1;

  /// No description provided for @privacyS4B2.
  ///
  /// In en, this message translates to:
  /// **'AWS S3 — Secure video storage'**
  String get privacyS4B2;

  /// No description provided for @privacyS4B3.
  ///
  /// In en, this message translates to:
  /// **'Anthropic Claude API — AI reasoning engine'**
  String get privacyS4B3;

  /// No description provided for @privacyS4B4.
  ///
  /// In en, this message translates to:
  /// **'Node.js/Express backend — API layer'**
  String get privacyS4B4;

  /// No description provided for @privacyS5Title.
  ///
  /// In en, this message translates to:
  /// **'Your Rights'**
  String get privacyS5Title;

  /// No description provided for @privacyS5Body.
  ///
  /// In en, this message translates to:
  /// **'You have full control over your data. You may request access, correction, or deletion of your personal data at any time by contacting us.'**
  String get privacyS5Body;

  /// No description provided for @privacyS5B1.
  ///
  /// In en, this message translates to:
  /// **'Right to access your stored data'**
  String get privacyS5B1;

  /// No description provided for @privacyS5B2.
  ///
  /// In en, this message translates to:
  /// **'Right to request data deletion'**
  String get privacyS5B2;

  /// No description provided for @privacyS5B3.
  ///
  /// In en, this message translates to:
  /// **'Right to opt out of analytics'**
  String get privacyS5B3;

  /// No description provided for @privacyS5B4.
  ///
  /// In en, this message translates to:
  /// **'Right to data portability'**
  String get privacyS5B4;

  /// No description provided for @privacyS6Title.
  ///
  /// In en, this message translates to:
  /// **'Policy Updates'**
  String get privacyS6Title;

  /// No description provided for @privacyS6Body.
  ///
  /// In en, this message translates to:
  /// **'We may update this Privacy Policy periodically. Significant changes will be communicated via in-app notification. Continued use of VeriFrame after updates constitutes your acceptance of the revised policy.'**
  String get privacyS6Body;

  /// No description provided for @privacyContact.
  ///
  /// In en, this message translates to:
  /// **'Questions about this policy?\nveriframe.support@gmail.com'**
  String get privacyContact;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'DEEP LEARNING • AUTHENTICITY • TRUST'**
  String get aboutTagline;

  /// No description provided for @aboutHero.
  ///
  /// In en, this message translates to:
  /// **'An intelligent system that sees through the synthetic — protecting truth in a world of AI-generated deception.'**
  String get aboutHero;

  /// No description provided for @aboutMissionLabel.
  ///
  /// In en, this message translates to:
  /// **'OUR MISSION'**
  String get aboutMissionLabel;

  /// No description provided for @aboutMission.
  ///
  /// In en, this message translates to:
  /// **'VeriFrame was built to address one of the most pressing challenges of the AI era: the proliferation of synthetic and manipulated video content. Our mission is to provide accessible, explainable, and accurate deepfake detection — making digital trust possible for everyone from journalists to law enforcement.'**
  String get aboutMission;

  /// No description provided for @aboutDifferentLabel.
  ///
  /// In en, this message translates to:
  /// **'WHAT MAKES US DIFFERENT'**
  String get aboutDifferentLabel;

  /// No description provided for @aboutFeature1Title.
  ///
  /// In en, this message translates to:
  /// **'Agentic Reasoning Pipeline'**
  String get aboutFeature1Title;

  /// No description provided for @aboutFeature1Desc.
  ///
  /// In en, this message translates to:
  /// **'Unlike static ML classifiers, VeriFrame uses an AI agent that plans, reasons, and explains its detection process step by step — delivering transparent verdicts, not just predictions.'**
  String get aboutFeature1Desc;

  /// No description provided for @aboutFeature2Title.
  ///
  /// In en, this message translates to:
  /// **'Explainable AI Detection'**
  String get aboutFeature2Title;

  /// No description provided for @aboutFeature2Desc.
  ///
  /// In en, this message translates to:
  /// **'Every analysis includes a confidence score and human-readable explanation of why a video is flagged — empowering users to understand and trust the result.'**
  String get aboutFeature2Desc;

  /// No description provided for @aboutFeature3Title.
  ///
  /// In en, this message translates to:
  /// **'Mobile-First & Cloud-Powered'**
  String get aboutFeature3Title;

  /// No description provided for @aboutFeature3Desc.
  ///
  /// In en, this message translates to:
  /// **'Built with Flutter for seamless cross-platform access, backed by a Node.js API and Python agent engine — real-time deepfake analysis in your pocket.'**
  String get aboutFeature3Desc;

  /// No description provided for @aboutFeature4Title.
  ///
  /// In en, this message translates to:
  /// **'Real-Time Adaptation'**
  String get aboutFeature4Title;

  /// No description provided for @aboutFeature4Desc.
  ///
  /// In en, this message translates to:
  /// **'Our system continuously improves through feedback loops, keeping pace with rapidly evolving deepfake generation techniques.'**
  String get aboutFeature4Desc;

  /// No description provided for @aboutTechLabel.
  ///
  /// In en, this message translates to:
  /// **'TECHNOLOGY STACK'**
  String get aboutTechLabel;

  /// No description provided for @aboutAppsLabel.
  ///
  /// In en, this message translates to:
  /// **'APPLICATIONS'**
  String get aboutAppsLabel;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0 • Build 2025'**
  String get aboutVersion;

  /// No description provided for @aboutBeta.
  ///
  /// In en, this message translates to:
  /// **'BETA'**
  String get aboutBeta;

  /// No description provided for @contactTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactTitle;

  /// No description provided for @contactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Have questions about VeriFrame? We\'re here to help.'**
  String get contactSubtitle;

  /// No description provided for @contactEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get contactEmail;

  /// No description provided for @contactResponseTime.
  ///
  /// In en, this message translates to:
  /// **'Response Time'**
  String get contactResponseTime;

  /// No description provided for @contactResponseValue.
  ///
  /// In en, this message translates to:
  /// **'24–48 hours'**
  String get contactResponseValue;

  /// No description provided for @contactSendMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'SEND A MESSAGE'**
  String get contactSendMessageLabel;

  /// No description provided for @contactYourName.
  ///
  /// In en, this message translates to:
  /// **'Your Name'**
  String get contactYourName;

  /// No description provided for @contactNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Kavindu Perera'**
  String get contactNameHint;

  /// No description provided for @contactNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get contactNameRequired;

  /// No description provided for @contactEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get contactEmailAddress;

  /// No description provided for @contactEmailHint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get contactEmailHint;

  /// No description provided for @contactEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get contactEmailRequired;

  /// No description provided for @contactEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get contactEmailInvalid;

  /// No description provided for @contactCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get contactCategory;

  /// No description provided for @contactSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get contactSubject;

  /// No description provided for @contactSubjectHint.
  ///
  /// In en, this message translates to:
  /// **'Brief description of your inquiry'**
  String get contactSubjectHint;

  /// No description provided for @contactSubjectRequired.
  ///
  /// In en, this message translates to:
  /// **'Subject is required'**
  String get contactSubjectRequired;

  /// No description provided for @contactMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get contactMessage;

  /// No description provided for @contactMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your question or issue in detail...'**
  String get contactMessageHint;

  /// No description provided for @contactMessageRequired.
  ///
  /// In en, this message translates to:
  /// **'Message is required'**
  String get contactMessageRequired;

  /// No description provided for @contactMessageMin.
  ///
  /// In en, this message translates to:
  /// **'Please provide more detail (min 20 characters)'**
  String get contactMessageMin;

  /// No description provided for @contactSend.
  ///
  /// In en, this message translates to:
  /// **'Send Message'**
  String get contactSend;

  /// No description provided for @contactSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Message Sent!'**
  String get contactSentTitle;

  /// No description provided for @contactSentBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ve received your message and will get back to you within 24–48 hours.'**
  String get contactSentBody;

  /// No description provided for @contactDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get contactDone;

  /// No description provided for @contactAlsoReach.
  ///
  /// In en, this message translates to:
  /// **'ALSO REACH US AT'**
  String get contactAlsoReach;

  /// No description provided for @contactCopied.
  ///
  /// In en, this message translates to:
  /// **'copied to clipboard'**
  String get contactCopied;

  /// No description provided for @catGeneral.
  ///
  /// In en, this message translates to:
  /// **'General Inquiry'**
  String get catGeneral;

  /// No description provided for @catBug.
  ///
  /// In en, this message translates to:
  /// **'Bug Report'**
  String get catBug;

  /// No description provided for @catFeature.
  ///
  /// In en, this message translates to:
  /// **'Feature Request'**
  String get catFeature;

  /// No description provided for @catPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Concern'**
  String get catPrivacy;

  /// No description provided for @catPartnership.
  ///
  /// In en, this message translates to:
  /// **'Partnership'**
  String get catPartnership;

  /// No description provided for @catResearch.
  ///
  /// In en, this message translates to:
  /// **'Research Collaboration'**
  String get catResearch;

  /// No description provided for @aboutHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'About VeriFrame'**
  String get aboutHeroTitle;

  /// No description provided for @appUse1.
  ///
  /// In en, this message translates to:
  /// **'Social Media Verification'**
  String get appUse1;

  /// No description provided for @appUse2.
  ///
  /// In en, this message translates to:
  /// **'Cybersecurity'**
  String get appUse2;

  /// No description provided for @appUse3.
  ///
  /// In en, this message translates to:
  /// **'News & Journalism'**
  String get appUse3;

  /// No description provided for @appUse4.
  ///
  /// In en, this message translates to:
  /// **'Law Enforcement'**
  String get appUse4;

  /// No description provided for @appUse5.
  ///
  /// In en, this message translates to:
  /// **'Digital Forensics'**
  String get appUse5;

  /// No description provided for @appUse6.
  ///
  /// In en, this message translates to:
  /// **'Academic Research'**
  String get appUse6;

  /// No description provided for @techRole1.
  ///
  /// In en, this message translates to:
  /// **'Frontend'**
  String get techRole1;

  /// No description provided for @techRole2.
  ///
  /// In en, this message translates to:
  /// **'Backend API'**
  String get techRole2;

  /// No description provided for @techRole3.
  ///
  /// In en, this message translates to:
  /// **'Agent Engine'**
  String get techRole3;

  /// No description provided for @techRole4.
  ///
  /// In en, this message translates to:
  /// **'AI Reasoning'**
  String get techRole4;

  /// No description provided for @techRole5.
  ///
  /// In en, this message translates to:
  /// **'Auth & Database'**
  String get techRole5;

  /// No description provided for @techRole6.
  ///
  /// In en, this message translates to:
  /// **'Media Storage'**
  String get techRole6;

  /// No description provided for @socialWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get socialWebsite;

  /// No description provided for @socialGithub.
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get socialGithub;

  /// No description provided for @socialLinkedin.
  ///
  /// In en, this message translates to:
  /// **'LinkedIn'**
  String get socialLinkedin;

  /// No description provided for @contactCompanyTitle.
  ///
  /// In en, this message translates to:
  /// **'Who We Are'**
  String get contactCompanyTitle;

  /// No description provided for @contactCompanyBody.
  ///
  /// In en, this message translates to:
  /// **'VeriFrame is a media-forensics technology company focused on detecting deepfakes and manipulated video. We work with newsrooms, researchers, and organizations that depend on trustworthy information.'**
  String get contactCompanyBody;

  /// No description provided for @contactSupportTitle.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get contactSupportTitle;

  /// No description provided for @contactSupportBody.
  ///
  /// In en, this message translates to:
  /// **'Our support team helps with account, analysis, and technical questions, and aims to reply within two business days.'**
  String get contactSupportBody;

  /// No description provided for @contactBusinessTitle.
  ///
  /// In en, this message translates to:
  /// **'Business Inquiries'**
  String get contactBusinessTitle;

  /// No description provided for @contactBusinessBody.
  ///
  /// In en, this message translates to:
  /// **'For partnerships, research collaboration, or enterprise verification, reach our business team and we will respond promptly.'**
  String get contactBusinessBody;

  /// No description provided for @contactOfficeLabel.
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get contactOfficeLabel;

  /// No description provided for @contactOfficeValue.
  ///
  /// In en, this message translates to:
  /// **'Suwasiripaya, Colombo 10, Sri Lanka'**
  String get contactOfficeValue;

  /// No description provided for @contactPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get contactPhoneLabel;

  /// No description provided for @contactPhoneValue.
  ///
  /// In en, this message translates to:
  /// **'+94 11 269 4033'**
  String get contactPhoneValue;

  /// No description provided for @contactHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'Working Hours'**
  String get contactHoursTitle;

  /// No description provided for @contactHoursBody.
  ///
  /// In en, this message translates to:
  /// **'Monday to Friday, 9:00 AM – 6:00 PM (GMT+5:30). Closed on public holidays.'**
  String get contactHoursBody;

  /// No description provided for @contactFaqTitle.
  ///
  /// In en, this message translates to:
  /// **'Frequently Asked Questions'**
  String get contactFaqTitle;

  /// No description provided for @faq1Q.
  ///
  /// In en, this message translates to:
  /// **'Is my video stored after analysis?'**
  String get faq1Q;

  /// No description provided for @faq1A.
  ///
  /// In en, this message translates to:
  /// **'By default your media is processed on your device and is not uploaded or stored permanently without your consent.'**
  String get faq1A;

  /// No description provided for @faq2Q.
  ///
  /// In en, this message translates to:
  /// **'How accurate is the detection?'**
  String get faq2Q;

  /// No description provided for @faq2A.
  ///
  /// In en, this message translates to:
  /// **'Accuracy depends on the model and media quality. VeriFrame always shows a confidence score and the evidence behind a result rather than a simple yes or no.'**
  String get faq2A;

  /// No description provided for @faq3Q.
  ///
  /// In en, this message translates to:
  /// **'Which languages are supported?'**
  String get faq3Q;

  /// No description provided for @faq3A.
  ///
  /// In en, this message translates to:
  /// **'The app is available in English, Sinhala, and Tamil, and we are working to add more.'**
  String get faq3A;

  /// No description provided for @faq4Q.
  ///
  /// In en, this message translates to:
  /// **'Is VeriFrame free to use?'**
  String get faq4Q;

  /// No description provided for @faq4A.
  ///
  /// In en, this message translates to:
  /// **'Core verification is available to use, with advanced reporting and enterprise features offered for teams and organizations.'**
  String get faq4A;

  /// No description provided for @contactSocialTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect With Us'**
  String get contactSocialTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeSystemHint.
  ///
  /// In en, this message translates to:
  /// **'Match my device'**
  String get settingsThemeSystemHint;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About VeriFrame'**
  String get settingsAbout;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacy;

  /// No description provided for @settingsContact.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get settingsContact;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source Licenses'**
  String get settingsLicenses;

  /// No description provided for @settingsThemeUpdated.
  ///
  /// In en, this message translates to:
  /// **'Theme updated'**
  String get settingsThemeUpdated;

  /// No description provided for @settingsLanguageUpdated.
  ///
  /// In en, this message translates to:
  /// **'Language updated'**
  String get settingsLanguageUpdated;

  /// No description provided for @settingsThemeSectionHint.
  ///
  /// In en, this message translates to:
  /// **'Choose how VeriFrame looks'**
  String get settingsThemeSectionHint;

  /// No description provided for @drawerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Media Forensics'**
  String get drawerSubtitle;

  /// No description provided for @drawerLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get drawerLanguage;

  /// No description provided for @aboutVisionLabel.
  ///
  /// In en, this message translates to:
  /// **'OUR VISION'**
  String get aboutVisionLabel;

  /// No description provided for @aboutVision.
  ///
  /// In en, this message translates to:
  /// **'A digital world where people can verify what they see before they share it — where synthetic media is clearly labelled and truth remains a shared foundation for public conversation.'**
  String get aboutVision;

  /// No description provided for @aboutWhyLabel.
  ///
  /// In en, this message translates to:
  /// **'WHY VERI_FRAME EXISTS'**
  String get aboutWhyLabel;

  /// No description provided for @aboutWhy.
  ///
  /// In en, this message translates to:
  /// **'Cheap, convincing deepfakes now threaten journalism, elections, businesses and personal reputations. Existing detection tools are opaque, expensive or locked inside labs. VeriFrame exists to put transparent, explainable verification into the hands of the people who need it most.'**
  String get aboutWhy;

  /// No description provided for @aboutTech.
  ///
  /// In en, this message translates to:
  /// **'VeriFrame runs EfficientViT and CrossEfficientViT models directly on your device for fast, private analysis, and pairs them with an explainable reasoning engine that highlights the evidence behind every verdict.'**
  String get aboutTech;

  /// No description provided for @aboutTechBody.
  ///
  /// In en, this message translates to:
  /// **'Built on EfficientViT and CrossEfficientViT models with an explainable reasoning engine that highlights the evidence behind every result.'**
  String get aboutTechBody;

  /// No description provided for @aboutStatVerificationsValue.
  ///
  /// In en, this message translates to:
  /// **'10K+'**
  String get aboutStatVerificationsValue;

  /// No description provided for @aboutStatVerificationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Verifications'**
  String get aboutStatVerificationsLabel;

  /// No description provided for @aboutStatRatingValue.
  ///
  /// In en, this message translates to:
  /// **'4.9'**
  String get aboutStatRatingValue;

  /// No description provided for @aboutStatRatingLabel.
  ///
  /// In en, this message translates to:
  /// **'User Rating'**
  String get aboutStatRatingLabel;

  /// No description provided for @aboutStatUptimeValue.
  ///
  /// In en, this message translates to:
  /// **'99.9%'**
  String get aboutStatUptimeValue;

  /// No description provided for @aboutStatUptimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Uptime'**
  String get aboutStatUptimeLabel;

  /// No description provided for @aboutStoryLabel.
  ///
  /// In en, this message translates to:
  /// **'OUR STORY'**
  String get aboutStoryLabel;

  /// No description provided for @aboutStory.
  ///
  /// In en, this message translates to:
  /// **'VeriFrame began as a research project to make deepfake detection transparent and accessible. Today it brings on-device forensic analysis and explainable AI to everyone.'**
  String get aboutStory;

  /// No description provided for @aboutValueOne.
  ///
  /// In en, this message translates to:
  /// **'Uncompromising Forensic Integrity'**
  String get aboutValueOne;

  /// No description provided for @aboutValueTwo.
  ///
  /// In en, this message translates to:
  /// **'Calibrated AI Deepfake Rigor'**
  String get aboutValueTwo;

  /// No description provided for @aboutValueThree.
  ///
  /// In en, this message translates to:
  /// **'Transparent & Actionable Intelligence'**
  String get aboutValueThree;

  /// No description provided for @aboutValuesLabel.
  ///
  /// In en, this message translates to:
  /// **'OUR VALUES'**
  String get aboutValuesLabel;

  /// No description provided for @aboutValue1Title.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get aboutValue1Title;

  /// No description provided for @aboutValue1Body.
  ///
  /// In en, this message translates to:
  /// **'We measure ourselves by how often we are right, and we are honest about uncertainty.'**
  String get aboutValue1Body;

  /// No description provided for @aboutValue2Title.
  ///
  /// In en, this message translates to:
  /// **'Transparency'**
  String get aboutValue2Title;

  /// No description provided for @aboutValue2Body.
  ///
  /// In en, this message translates to:
  /// **'Every verdict comes with the evidence behind it — never a black box.'**
  String get aboutValue2Body;

  /// No description provided for @aboutValue3Title.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get aboutValue3Title;

  /// No description provided for @aboutValue3Body.
  ///
  /// In en, this message translates to:
  /// **'Your media stays on your device unless you choose to share it.'**
  String get aboutValue3Body;

  /// No description provided for @aboutValue4Title.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get aboutValue4Title;

  /// No description provided for @aboutValue4Body.
  ///
  /// In en, this message translates to:
  /// **'Verification should be available to everyone, on the devices they already own.'**
  String get aboutValue4Body;

  /// No description provided for @aboutCommitmentLabel.
  ///
  /// In en, this message translates to:
  /// **'OUR COMMITMENT TO USERS'**
  String get aboutCommitmentLabel;

  /// No description provided for @aboutCommitment.
  ///
  /// In en, this message translates to:
  /// **'We will never sell your personal data, we keep analysis on your device by default, and we are clear about the limits of what our models can detect. When we get something wrong, we say so.'**
  String get aboutCommitment;

  /// No description provided for @aboutSecurityLabel.
  ///
  /// In en, this message translates to:
  /// **'SECURITY & PRIVACY'**
  String get aboutSecurityLabel;

  /// No description provided for @aboutSecurity.
  ///
  /// In en, this message translates to:
  /// **'Uploaded media is processed locally where possible and is not stored permanently without your consent. Data in transit and at rest is encrypted, and access is protected by industry-standard authentication.'**
  String get aboutSecurity;

  /// No description provided for @aboutRoadmapLabel.
  ///
  /// In en, this message translates to:
  /// **'WHAT\'S NEXT'**
  String get aboutRoadmapLabel;

  /// No description provided for @aboutRoadmap.
  ///
  /// In en, this message translates to:
  /// **'We are expanding language support, adding image and audio verification, improving performance on low-end devices, and partnering with newsrooms and fact-checkers to keep pace with new manipulation techniques.'**
  String get aboutRoadmap;

  /// No description provided for @aboutClosing.
  ///
  /// In en, this message translates to:
  /// **'VeriFrame is built by a small team that cares about truth online. If you have feedback, ideas, or want to work with us, we would love to hear from you.'**
  String get aboutClosing;

  /// No description provided for @profileChangePhotoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Change Profile Picture'**
  String get profileChangePhotoTooltip;

  /// No description provided for @profileRemovePhotoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove Profile Picture'**
  String get profileRemovePhotoTooltip;

  /// No description provided for @profileFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to Load'**
  String get profileFailedToLoad;

  /// No description provided for @profileNoPhoto.
  ///
  /// In en, this message translates to:
  /// **'No Photo'**
  String get profileNoPhoto;

  /// No description provided for @profileEmailReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Email (Read-only)'**
  String get profileEmailReadOnly;

  /// No description provided for @profileNewPasswordOptional.
  ///
  /// In en, this message translates to:
  /// **'New Password (Optional)'**
  String get profileNewPasswordOptional;

  /// No description provided for @profileTipsTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile Tips:'**
  String get profileTipsTitle;

  /// No description provided for @profileTip1.
  ///
  /// In en, this message translates to:
  /// **'Profile photo is optional - you can add, change, or remove it anytime'**
  String get profileTip1;

  /// No description provided for @profileTip2.
  ///
  /// In en, this message translates to:
  /// **'Leave password field empty if you don\'t want to change it'**
  String get profileTip2;

  /// No description provided for @profileTip3.
  ///
  /// In en, this message translates to:
  /// **'Email cannot be changed - contact support if needed'**
  String get profileTip3;

  /// No description provided for @profileTip4.
  ///
  /// In en, this message translates to:
  /// **'All other changes will be saved automatically'**
  String get profileTip4;

  /// No description provided for @profileNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get profileNameRequired;

  /// No description provided for @profileUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdatedSuccessfully;

  /// No description provided for @profilePhotoRemoved.
  ///
  /// In en, this message translates to:
  /// **'Profile photo removed'**
  String get profilePhotoRemoved;

  /// No description provided for @verifyVideoTab.
  ///
  /// In en, this message translates to:
  /// **'VIDEO'**
  String get verifyVideoTab;

  /// No description provided for @verifyLinkTab.
  ///
  /// In en, this message translates to:
  /// **'LINK'**
  String get verifyLinkTab;

  /// No description provided for @verifyStreamTab.
  ///
  /// In en, this message translates to:
  /// **'STREAM'**
  String get verifyStreamTab;

  /// No description provided for @verifyAiForensicTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Forensic Deepfake Verification'**
  String get verifyAiForensicTitle;

  /// No description provided for @verifyNoBackendUrl.
  ///
  /// In en, this message translates to:
  /// **'No backend URL set — on-device TFLite inference will run automatically.'**
  String get verifyNoBackendUrl;

  /// No description provided for @verifySelectLocalVideo.
  ///
  /// In en, this message translates to:
  /// **'Select a local MP4/MOV video clip. VeriFrame runs boundary blending, temporal flicker, and spatial transformer checks.'**
  String get verifySelectLocalVideo;

  /// No description provided for @verifyOnDeviceReady.
  ///
  /// In en, this message translates to:
  /// **'On-device model ready'**
  String get verifyOnDeviceReady;

  /// No description provided for @verifyModelLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Model load failed'**
  String get verifyModelLoadFailed;

  /// No description provided for @verifyLoadingModel.
  ///
  /// In en, this message translates to:
  /// **'Loading model…'**
  String get verifyLoadingModel;

  /// No description provided for @verifyPickLocalVideo.
  ///
  /// In en, this message translates to:
  /// **'Pick Local Video'**
  String get verifyPickLocalVideo;

  /// No description provided for @verifyVideoUrlPaste.
  ///
  /// In en, this message translates to:
  /// **'Video URL Paste'**
  String get verifyVideoUrlPaste;

  /// No description provided for @verifyUrlScanDescription.
  ///
  /// In en, this message translates to:
  /// **'Scan clips directly from social media links.'**
  String get verifyUrlScanDescription;

  /// No description provided for @verifyUrlHintExample.
  ///
  /// In en, this message translates to:
  /// **'https://youtube.com/... or direct MP4 link'**
  String get verifyUrlHintExample;

  /// No description provided for @verifyAnalyzeUrlClip.
  ///
  /// In en, this message translates to:
  /// **'Analyze URL Clip'**
  String get verifyAnalyzeUrlClip;

  /// No description provided for @verifyExternalLiveStream.
  ///
  /// In en, this message translates to:
  /// **'External Live Stream'**
  String get verifyExternalLiveStream;

  /// No description provided for @verifyStreamDescription.
  ///
  /// In en, this message translates to:
  /// **'Analyze live video streams (RTSP, HLS, RTMP) in real-time. The server will pull frames automatically.'**
  String get verifyStreamDescription;

  /// No description provided for @verifyStreamUrlHint.
  ///
  /// In en, this message translates to:
  /// **'rtsp://example.com/live or .m3u8 HLS url'**
  String get verifyStreamUrlHint;

  /// No description provided for @verifyDeviceCameraFeed.
  ///
  /// In en, this message translates to:
  /// **'Device Camera Feed'**
  String get verifyDeviceCameraFeed;

  /// No description provided for @verifyCameraStreamDescription.
  ///
  /// In en, this message translates to:
  /// **'Stream base64 frames directly from your device camera to the AI engine.'**
  String get verifyCameraStreamDescription;

  /// No description provided for @verifyOpenCameraStream.
  ///
  /// In en, this message translates to:
  /// **'Open Camera Stream'**
  String get verifyOpenCameraStream;

  /// No description provided for @verifyForensicConclusion.
  ///
  /// In en, this message translates to:
  /// **'FORENSIC CONCLUSION'**
  String get verifyForensicConclusion;

  /// No description provided for @verifyModelUsed.
  ///
  /// In en, this message translates to:
  /// **'Model Used:'**
  String get verifyModelUsed;

  /// No description provided for @verifyExplainableAiStatement.
  ///
  /// In en, this message translates to:
  /// **'EXPLAINABLE AI STATEMENT'**
  String get verifyExplainableAiStatement;

  /// No description provided for @verifyGetReportPdf.
  ///
  /// In en, this message translates to:
  /// **'Get Report PDF'**
  String get verifyGetReportPdf;

  /// No description provided for @verifyReportMedia.
  ///
  /// In en, this message translates to:
  /// **'Report Media'**
  String get verifyReportMedia;

  /// No description provided for @verifyScanAnotherMedia.
  ///
  /// In en, this message translates to:
  /// **'Scan Another Media'**
  String get verifyScanAnotherMedia;

  /// No description provided for @verifyAiAnalyzingStream.
  ///
  /// In en, this message translates to:
  /// **'AI ANALYZING STREAM URL...'**
  String get verifyAiAnalyzingStream;

  /// No description provided for @verifyFeedStreaming.
  ///
  /// In en, this message translates to:
  /// **'FEED STREAMING...'**
  String get verifyFeedStreaming;

  /// No description provided for @verifyStopGetReport.
  ///
  /// In en, this message translates to:
  /// **'Stop & Get Report'**
  String get verifyStopGetReport;

  /// No description provided for @verifyEscalateTitle.
  ///
  /// In en, this message translates to:
  /// **'Escalate to Sri Lanka Authorities'**
  String get verifyEscalateTitle;

  /// No description provided for @verifyEscalateDescription.
  ///
  /// In en, this message translates to:
  /// **'This report is eligible for escalation based on high deepfake confidence score (>=75%). Select authority target:'**
  String get verifyEscalateDescription;

  /// No description provided for @verifyEscalationAgency.
  ///
  /// In en, this message translates to:
  /// **'Escalation Agency'**
  String get verifyEscalationAgency;

  /// No description provided for @verifySriLankaPolice.
  ///
  /// In en, this message translates to:
  /// **'Sri Lanka Police (Cyber Crime)'**
  String get verifySriLankaPolice;

  /// No description provided for @verifyCertCc.
  ///
  /// In en, this message translates to:
  /// **'Sri Lanka CERT|CC'**
  String get verifyCertCc;

  /// No description provided for @verifyEscalateConfirm.
  ///
  /// In en, this message translates to:
  /// **'I confirm the details in the forensic report are accurate to the best of my knowledge.'**
  String get verifyEscalateConfirm;

  /// No description provided for @verifyEscalateConsent.
  ///
  /// In en, this message translates to:
  /// **'I consent to share this video and analysis data with the selected authorities.'**
  String get verifyEscalateConsent;

  /// No description provided for @verifyCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get verifyCancel;

  /// No description provided for @verifySubmitEscalation.
  ///
  /// In en, this message translates to:
  /// **'Submit Escalation'**
  String get verifySubmitEscalation;

  /// No description provided for @verifyBackendUrlTitle.
  ///
  /// In en, this message translates to:
  /// **'Backend URL'**
  String get verifyBackendUrlTitle;

  /// No description provided for @verifyBackendUrlHelper.
  ///
  /// In en, this message translates to:
  /// **'Use your PC LAN IP for a physical phone. Emulator: http://10.0.2.2:8000'**
  String get verifyBackendUrlHelper;

  /// No description provided for @verifyBackendSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get verifyBackendSave;

  /// No description provided for @verifyEnterVideoUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter video URL...'**
  String get verifyEnterVideoUrl;

  /// No description provided for @verifyNoCameras.
  ///
  /// In en, this message translates to:
  /// **'No cameras available on this device.'**
  String get verifyNoCameras;

  /// No description provided for @verifyCameraError.
  ///
  /// In en, this message translates to:
  /// **'Camera error: {error}'**
  String verifyCameraError(Object error);

  /// No description provided for @verifyUnsupportedFormat.
  ///
  /// In en, this message translates to:
  /// **'Unsupported video format. Please use MP4, MOV, MKV, or AVI.'**
  String get verifyUnsupportedFormat;

  /// No description provided for @verifyConnectingServer.
  ///
  /// In en, this message translates to:
  /// **'Connecting to forensic server...'**
  String get verifyConnectingServer;

  /// No description provided for @verifyBackendOffline.
  ///
  /// In en, this message translates to:
  /// **'Backend offline — switching to on-device analysis.'**
  String get verifyBackendOffline;

  /// No description provided for @verifyUploadingFile.
  ///
  /// In en, this message translates to:
  /// **'Uploading video file...'**
  String get verifyUploadingFile;

  /// No description provided for @verifyUploadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Uploading... {percent}%'**
  String verifyUploadingProgress(Object percent);

  /// No description provided for @verifyAggregatingPredictions.
  ///
  /// In en, this message translates to:
  /// **'Aggregating predictions...'**
  String get verifyAggregatingPredictions;

  /// No description provided for @verifyOfflineModelFailed.
  ///
  /// In en, this message translates to:
  /// **'Offline model failed: {error}'**
  String verifyOfflineModelFailed(Object error);

  /// No description provided for @verifyModelLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading model...'**
  String get verifyModelLoading;

  /// No description provided for @verifyValidatingFile.
  ///
  /// In en, this message translates to:
  /// **'Validating file...'**
  String get verifyValidatingFile;

  /// No description provided for @verifyExtractingFrames.
  ///
  /// In en, this message translates to:
  /// **'Extracting frames...'**
  String get verifyExtractingFrames;

  /// No description provided for @verifyAnalyzingFrame.
  ///
  /// In en, this message translates to:
  /// **'Analyzing frame {current} of {total}...'**
  String verifyAnalyzingFrame(Object current, Object total);

  /// No description provided for @verifyDetectingRegions.
  ///
  /// In en, this message translates to:
  /// **'Detecting facial regions...'**
  String get verifyDetectingRegions;

  /// No description provided for @verifyPreparingTensors.
  ///
  /// In en, this message translates to:
  /// **'Preparing tensors...'**
  String get verifyPreparingTensors;

  /// No description provided for @verifyRunningInference.
  ///
  /// In en, this message translates to:
  /// **'Running inference...'**
  String get verifyRunningInference;

  /// No description provided for @verifyInferenceFailed.
  ///
  /// In en, this message translates to:
  /// **'Inference failed. Please try again.'**
  String get verifyInferenceFailed;

  /// No description provided for @verifyPleasePasteUrl.
  ///
  /// In en, this message translates to:
  /// **'Please paste a video URL first.'**
  String get verifyPleasePasteUrl;

  /// No description provided for @verifyDownloadingVideo.
  ///
  /// In en, this message translates to:
  /// **'Downloading video...'**
  String get verifyDownloadingVideo;

  /// No description provided for @verifyFeatureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Feature unavailable while offline.'**
  String get verifyFeatureUnavailable;

  /// No description provided for @verifyPollingTimeout.
  ///
  /// In en, this message translates to:
  /// **'Analysis timed out. Please try again.'**
  String get verifyPollingTimeout;

  /// No description provided for @verifyEnterStreamUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a stream URL first.'**
  String get verifyEnterStreamUrl;

  /// No description provided for @verifyCompilingSessionReport.
  ///
  /// In en, this message translates to:
  /// **'Compiling session report...'**
  String get verifyCompilingSessionReport;

  /// No description provided for @verifyLocalReportExplanation.
  ///
  /// In en, this message translates to:
  /// **'Analyzed {frames} frames with {score}% average confidence.'**
  String verifyLocalReportExplanation(Object frames, Object score);

  /// No description provided for @verifyAuthError.
  ///
  /// In en, this message translates to:
  /// **'You must be signed in to verify media.'**
  String get verifyAuthError;

  /// No description provided for @verifyCompilingForensicReport.
  ///
  /// In en, this message translates to:
  /// **'Compiling forensic report...'**
  String get verifyCompilingForensicReport;

  /// No description provided for @verifyNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification Complete'**
  String get verifyNotificationTitle;

  /// No description provided for @verifyNotificationTitleBranded.
  ///
  /// In en, this message translates to:
  /// **'VeriFrame Verification Complete'**
  String get verifyNotificationTitleBranded;

  /// No description provided for @verifyCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Analysis Complete'**
  String get verifyCompleteTitle;

  /// No description provided for @verifyVerdictLabel.
  ///
  /// In en, this message translates to:
  /// **'VERDICT'**
  String get verifyVerdictLabel;

  /// No description provided for @verifyAuthenticityLabel.
  ///
  /// In en, this message translates to:
  /// **'AUTHENTICITY'**
  String get verifyAuthenticityLabel;

  /// No description provided for @verifyManipulationLabel.
  ///
  /// In en, this message translates to:
  /// **'MANIPULATION'**
  String get verifyManipulationLabel;

  /// No description provided for @verifyConfidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'CONFIDENCE'**
  String get verifyConfidenceLabel;

  /// No description provided for @verifyRiskLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'RISK LEVEL'**
  String get verifyRiskLevelLabel;

  /// No description provided for @verifyVerifiedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'VERIFIED AT'**
  String get verifyVerifiedAtLabel;

  /// No description provided for @verifyViewHistory.
  ///
  /// In en, this message translates to:
  /// **'View History'**
  String get verifyViewHistory;

  /// No description provided for @verifyDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get verifyDone;

  /// No description provided for @verifyGeneratingPdf.
  ///
  /// In en, this message translates to:
  /// **'Generating PDF report...'**
  String get verifyGeneratingPdf;

  /// No description provided for @verifyPdfFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate PDF: {error}'**
  String verifyPdfFailed(Object error);

  /// No description provided for @verifyLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Report link copied to clipboard.'**
  String get verifyLinkCopied;

  /// No description provided for @reportErrorOpeningPdf.
  ///
  /// In en, this message translates to:
  /// **'Error opening PDF: {error}'**
  String reportErrorOpeningPdf(Object error);

  /// No description provided for @reportIdCopied.
  ///
  /// In en, this message translates to:
  /// **'Report ID copied: {id}'**
  String reportIdCopied(Object id);

  /// No description provided for @reportCopyId.
  ///
  /// In en, this message translates to:
  /// **'Copy report ID'**
  String get reportCopyId;

  /// No description provided for @verifyEscalationFailed.
  ///
  /// In en, this message translates to:
  /// **'Escalation failed: {error}'**
  String verifyEscalationFailed(Object error);

  /// No description provided for @verifyAnalyzeStream.
  ///
  /// In en, this message translates to:
  /// **'Analyze Stream'**
  String get verifyAnalyzeStream;

  /// No description provided for @verifyCancelScan.
  ///
  /// In en, this message translates to:
  /// **'Cancel Scan'**
  String get verifyCancelScan;

  /// No description provided for @verifyStepFormatValidation.
  ///
  /// In en, this message translates to:
  /// **'Format Validation'**
  String get verifyStepFormatValidation;

  /// No description provided for @verifyStepFrameExtraction.
  ///
  /// In en, this message translates to:
  /// **'Frame Extraction'**
  String get verifyStepFrameExtraction;

  /// No description provided for @verifyStepFaceDetection.
  ///
  /// In en, this message translates to:
  /// **'Face Detection'**
  String get verifyStepFaceDetection;

  /// No description provided for @verifyStepModelInference.
  ///
  /// In en, this message translates to:
  /// **'Model Inference'**
  String get verifyStepModelInference;

  /// No description provided for @verifyStepGeneratingReasoning.
  ///
  /// In en, this message translates to:
  /// **'Generating Reasoning'**
  String get verifyStepGeneratingReasoning;

  /// No description provided for @verifyStepGeneratingPdf.
  ///
  /// In en, this message translates to:
  /// **'Generating PDF'**
  String get verifyStepGeneratingPdf;

  /// No description provided for @verifyStepSendingNotification.
  ///
  /// In en, this message translates to:
  /// **'Sending Notification'**
  String get verifyStepSendingNotification;

  /// No description provided for @verifyStepCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get verifyStepCompleted;

  /// No description provided for @verifyLinkStepRequestInitiated.
  ///
  /// In en, this message translates to:
  /// **'Request Initiated'**
  String get verifyLinkStepRequestInitiated;

  /// No description provided for @verifyLinkStepDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get verifyLinkStepDownloading;

  /// No description provided for @verifyLinkStepExtracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting Frames'**
  String get verifyLinkStepExtracting;

  /// No description provided for @verifyLinkStepDetecting.
  ///
  /// In en, this message translates to:
  /// **'Detecting Faces'**
  String get verifyLinkStepDetecting;

  /// No description provided for @verifyLinkStepInference.
  ///
  /// In en, this message translates to:
  /// **'Running Inference'**
  String get verifyLinkStepInference;

  /// No description provided for @verifyConnectingLiveStream.
  ///
  /// In en, this message translates to:
  /// **'Connecting to live stream...'**
  String get verifyConnectingLiveStream;

  /// No description provided for @verifyFpsFrames.
  ///
  /// In en, this message translates to:
  /// **'{fps} FPS · {frames} frames'**
  String verifyFpsFrames(Object fps, Object frames);

  /// No description provided for @verifyCurrentProbability.
  ///
  /// In en, this message translates to:
  /// **'Current Probability'**
  String get verifyCurrentProbability;

  /// No description provided for @verifyProbabilityGraph.
  ///
  /// In en, this message translates to:
  /// **'Probability Graph'**
  String get verifyProbabilityGraph;

  /// No description provided for @verifyLandmarkMap.
  ///
  /// In en, this message translates to:
  /// **'Landmark map: {count} points'**
  String verifyLandmarkMap(Object count);

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'This action permanently removes your account and forensic history. This cannot be undone.'**
  String get deleteAccountMessage;

  /// No description provided for @deletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete Permanently'**
  String get deletePermanently;

  /// No description provided for @homeStatsAiModels.
  ///
  /// In en, this message translates to:
  /// **'AI Models'**
  String get homeStatsAiModels;

  /// No description provided for @homeStatsRealtime.
  ///
  /// In en, this message translates to:
  /// **'Real-time'**
  String get homeStatsRealtime;

  /// No description provided for @homeStatsLiveAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Live analysis'**
  String get homeStatsLiveAnalysis;

  /// No description provided for @homeStatsForensic.
  ///
  /// In en, this message translates to:
  /// **'Forensic'**
  String get homeStatsForensic;

  /// No description provided for @homeStatsEvidenceReports.
  ///
  /// In en, this message translates to:
  /// **'Evidence reports'**
  String get homeStatsEvidenceReports;

  /// No description provided for @homeFooterTagline.
  ///
  /// In en, this message translates to:
  /// **'Media forensics for a trustworthy internet.'**
  String get homeFooterTagline;

  /// No description provided for @homeCopyright.
  ///
  /// In en, this message translates to:
  /// **'© {year} VeriFrame. All rights reserved.'**
  String homeCopyright(Object year);

  /// No description provided for @verifyBackendServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Configure Backend Server'**
  String get verifyBackendServerTitle;

  /// No description provided for @verifyBackendUrlHint.
  ///
  /// In en, this message translates to:
  /// **'http://192.168.1.100:8000'**
  String get verifyBackendUrlHint;

  /// No description provided for @verifyBackendHelper.
  ///
  /// In en, this message translates to:
  /// **'Specify host base address (use LAN IP on physical phones)'**
  String get verifyBackendHelper;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read ({count})'**
  String notificationsMarkAllRead(Object count);

  /// No description provided for @notificationsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete notification?'**
  String get notificationsDeleteTitle;

  /// No description provided for @notificationsDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This notification will be permanently removed.'**
  String get notificationsDeleteMessage;

  /// No description provided for @notificationsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get notificationsDeleteConfirm;

  /// No description provided for @notificationsDeleteAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all notifications?'**
  String get notificationsDeleteAllTitle;

  /// No description provided for @notificationsDeleteAllMessage.
  ///
  /// In en, this message translates to:
  /// **'All notifications will be permanently deleted. This cannot be undone.'**
  String get notificationsDeleteAllMessage;

  /// No description provided for @notificationsDeleteAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete All'**
  String get notificationsDeleteAllConfirm;

  /// No description provided for @notificationsNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'User not logged in.'**
  String get notificationsNotLoggedIn;

  /// No description provided for @notificationsError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String notificationsError(Object error);

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted successfully.'**
  String get accountDeleted;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Forensic reports'**
  String get reportsTitle;

  /// No description provided for @reportsHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Video history'**
  String get reportsHistoryTitle;

  /// No description provided for @reportsHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'History of media Verification'**
  String get reportsHistorySubtitle;

  /// No description provided for @reportsNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'User not logged in.'**
  String get reportsNotLoggedIn;

  /// No description provided for @reportsNoReports.
  ///
  /// In en, this message translates to:
  /// **'No reports yet\nYour completed forensic analyses will appear here once a verification has finished.'**
  String get reportsNoReports;

  /// No description provided for @reportsForensicVerification.
  ///
  /// In en, this message translates to:
  /// **'Forensic verification'**
  String get reportsForensicVerification;

  /// No description provided for @reportsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete report'**
  String get reportsDeleteTitle;

  /// No description provided for @reportsDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove \"{name}\"? This action cannot be undone.'**
  String reportsDeleteMessage(Object name);

  /// No description provided for @reportsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get reportsDeleteConfirm;

  /// No description provided for @reportsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Report deleted'**
  String get reportsDeleted;

  /// No description provided for @reportsDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete report: {error}'**
  String reportsDeleteFailed(Object error);

  /// No description provided for @reportsDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete report'**
  String get reportsDeleteTooltip;

  /// No description provided for @reportsDeleteAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all reports?'**
  String get reportsDeleteAllTitle;

  /// No description provided for @reportsDeleteAllMessage.
  ///
  /// In en, this message translates to:
  /// **'All reports will be permanently deleted. This cannot be undone.'**
  String get reportsDeleteAllMessage;

  /// No description provided for @reportsDeleteAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete All'**
  String get reportsDeleteAllConfirm;

  /// No description provided for @techStackTitle.
  ///
  /// In en, this message translates to:
  /// **'Technology Stack'**
  String get techStackTitle;

  /// No description provided for @techStackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The technologies powering VeriFrame\'s forensic deepfake detection platform.'**
  String get techStackSubtitle;

  /// No description provided for @notificationsJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get notificationsJustNow;

  /// No description provided for @notificationsMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String notificationsMinutesAgo(Object count);

  /// No description provided for @notificationsHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String notificationsHoursAgo(Object count);

  /// No description provided for @notificationsDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String notificationsDaysAgo(Object count);

  /// No description provided for @notificationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Notifications'**
  String get notificationsEmptyTitle;

  /// No description provided for @notificationsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up.\nNew verification results will appear here.'**
  String get notificationsEmptySubtitle;

  /// No description provided for @verifyAuthenticLabel.
  ///
  /// In en, this message translates to:
  /// **'AUTHENTIC'**
  String get verifyAuthenticLabel;

  /// No description provided for @verifyManipulatedLabel.
  ///
  /// In en, this message translates to:
  /// **'MANIPULATED'**
  String get verifyManipulatedLabel;

  /// No description provided for @cameraStopAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Stop & Analyze'**
  String get cameraStopAnalyze;

  /// No description provided for @cameraStartLiveStream.
  ///
  /// In en, this message translates to:
  /// **'Start Live Stream'**
  String get cameraStartLiveStream;

  /// No description provided for @cameraGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get cameraGoBack;

  /// No description provided for @cameraNoCamerasFound.
  ///
  /// In en, this message translates to:
  /// **'No cameras found'**
  String get cameraNoCamerasFound;

  /// No description provided for @cameraError.
  ///
  /// In en, this message translates to:
  /// **'Camera error: {error}'**
  String cameraError(Object error);

  /// No description provided for @cameraLiveStreamFrames.
  ///
  /// In en, this message translates to:
  /// **'Live Stream • {count} frames'**
  String cameraLiveStreamFrames(Object count);

  /// No description provided for @cameraInitializing.
  ///
  /// In en, this message translates to:
  /// **'Initializing Camera...'**
  String get cameraInitializing;

  /// No description provided for @verifyCancelAnalysis.
  ///
  /// In en, this message translates to:
  /// **'CANCEL ANALYSIS'**
  String get verifyCancelAnalysis;

  /// No description provided for @reportDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Forensic report'**
  String get reportDetailTitle;

  /// No description provided for @reportMediaScan.
  ///
  /// In en, this message translates to:
  /// **'Forensic media scan'**
  String get reportMediaScan;

  /// No description provided for @reportIdLabel.
  ///
  /// In en, this message translates to:
  /// **'ID {id}'**
  String reportIdLabel(Object id);

  /// No description provided for @reportSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get reportSourceLabel;

  /// No description provided for @reportVerifiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get reportVerifiedLabel;

  /// No description provided for @reportRiskLabel.
  ///
  /// In en, this message translates to:
  /// **'Risk'**
  String get reportRiskLabel;

  /// No description provided for @reportConfidenceAssessment.
  ///
  /// In en, this message translates to:
  /// **'Confidence assessment'**
  String get reportConfidenceAssessment;

  /// No description provided for @reportConfidenceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fused score across verification pipelines'**
  String get reportConfidenceSubtitle;

  /// No description provided for @reportConfidencePercent.
  ///
  /// In en, this message translates to:
  /// **'% confidence'**
  String get reportConfidencePercent;

  /// No description provided for @reportFusionConfidenceRating.
  ///
  /// In en, this message translates to:
  /// **'Fusion confidence rating'**
  String get reportFusionConfidenceRating;

  /// No description provided for @reportFusionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Model, frame and tracking scores combined into one rating.'**
  String get reportFusionSubtitle;

  /// No description provided for @reportPipelineMetrics.
  ///
  /// In en, this message translates to:
  /// **'Pipeline metrics'**
  String get reportPipelineMetrics;

  /// No description provided for @reportPipelineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deep-learning and structural verification checks'**
  String get reportPipelineSubtitle;

  /// No description provided for @reportFrameConsistency.
  ///
  /// In en, this message translates to:
  /// **'Frame consistency'**
  String get reportFrameConsistency;

  /// No description provided for @reportFrameConsistencyExplanation.
  ///
  /// In en, this message translates to:
  /// **'Frame-by-frame color histogram correlation. Low values indicate splicing.'**
  String get reportFrameConsistencyExplanation;

  /// No description provided for @reportBiometricFaceTracking.
  ///
  /// In en, this message translates to:
  /// **'Biometric face tracking'**
  String get reportBiometricFaceTracking;

  /// No description provided for @reportBiometricExplanation.
  ///
  /// In en, this message translates to:
  /// **'Temporal displacement variance of detected face bounding boxes.'**
  String get reportBiometricExplanation;

  /// No description provided for @reportMetadataValidation.
  ///
  /// In en, this message translates to:
  /// **'Metadata validation'**
  String get reportMetadataValidation;

  /// No description provided for @reportMetadataExplanation.
  ///
  /// In en, this message translates to:
  /// **'Container structure, FPS range and header integrity validation.'**
  String get reportMetadataExplanation;

  /// No description provided for @reportOcrConfidence.
  ///
  /// In en, this message translates to:
  /// **'OCR confidence'**
  String get reportOcrConfidence;

  /// No description provided for @reportOcrExplanation.
  ///
  /// In en, this message translates to:
  /// **'Presence and edge contour quality of static text overlays.'**
  String get reportOcrExplanation;

  /// No description provided for @reportExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get reportExport;

  /// No description provided for @reportExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate and share the official forensic document'**
  String get reportExportSubtitle;

  /// No description provided for @reportPdfForensicReport.
  ///
  /// In en, this message translates to:
  /// **'PDF forensic report'**
  String get reportPdfForensicReport;

  /// No description provided for @reportPdfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Signed, timestamped and court-ready export.'**
  String get reportPdfSubtitle;

  /// No description provided for @reportGeneratePdf.
  ///
  /// In en, this message translates to:
  /// **'Generate forensic PDF'**
  String get reportGeneratePdf;

  /// No description provided for @reportCompiling.
  ///
  /// In en, this message translates to:
  /// **'Compiling report...'**
  String get reportCompiling;

  /// No description provided for @reportShare.
  ///
  /// In en, this message translates to:
  /// **'Share report'**
  String get reportShare;

  /// No description provided for @timelineTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Forensic Verification Timeline'**
  String get timelineTitle;

  /// No description provided for @timelineStage.
  ///
  /// In en, this message translates to:
  /// **'Stage {current} / {total}'**
  String timelineStage(Object current, Object total);

  /// No description provided for @pipelineTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Verification Pipeline'**
  String get pipelineTitle;

  /// No description provided for @pipelineCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get pipelineCompleted;

  /// No description provided for @stagePreparingAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Preparing Analysis'**
  String get stagePreparingAnalysis;

  /// No description provided for @stageValidatingMedia.
  ///
  /// In en, this message translates to:
  /// **'Validating Media'**
  String get stageValidatingMedia;

  /// No description provided for @stageDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get stageDownloading;

  /// No description provided for @stageExtractingMetadata.
  ///
  /// In en, this message translates to:
  /// **'Extracting Metadata'**
  String get stageExtractingMetadata;

  /// No description provided for @stageSelectingFrames.
  ///
  /// In en, this message translates to:
  /// **'Selecting Frames'**
  String get stageSelectingFrames;

  /// No description provided for @stageDetectingFaces.
  ///
  /// In en, this message translates to:
  /// **'Detecting Faces'**
  String get stageDetectingFaces;

  /// No description provided for @stageTrackingFaces.
  ///
  /// In en, this message translates to:
  /// **'Tracking Faces'**
  String get stageTrackingFaces;

  /// No description provided for @stageAssessingQuality.
  ///
  /// In en, this message translates to:
  /// **'Assessing Quality'**
  String get stageAssessingQuality;

  /// No description provided for @stageRunningAiAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Running AI Analysis'**
  String get stageRunningAiAnalysis;

  /// No description provided for @stageVerifyingTemporalConsistency.
  ///
  /// In en, this message translates to:
  /// **'Verifying Temporal Consistency'**
  String get stageVerifyingTemporalConsistency;

  /// No description provided for @stageAggregatingEvidence.
  ///
  /// In en, this message translates to:
  /// **'Aggregating Evidence'**
  String get stageAggregatingEvidence;

  /// No description provided for @stageCalibratingConfidence.
  ///
  /// In en, this message translates to:
  /// **'Calibrating Confidence'**
  String get stageCalibratingConfidence;

  /// No description provided for @stageGeneratingReport.
  ///
  /// In en, this message translates to:
  /// **'Generating Report'**
  String get stageGeneratingReport;

  /// No description provided for @stageVerificationComplete.
  ///
  /// In en, this message translates to:
  /// **'Verification Complete'**
  String get stageVerificationComplete;

  /// No description provided for @mediaValidationLabel.
  ///
  /// In en, this message translates to:
  /// **'Media Validation'**
  String get mediaValidationLabel;

  /// No description provided for @mediaValidationDesc.
  ///
  /// In en, this message translates to:
  /// **'Validating media headers, SHA-256 hash, and format integrity...'**
  String get mediaValidationDesc;

  /// No description provided for @metadataInspectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Metadata Inspection'**
  String get metadataInspectionLabel;

  /// No description provided for @metadataInspectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Analyzing EXIF, container metadata, and timestamp consistency...'**
  String get metadataInspectionDesc;

  /// No description provided for @frameExtractionLabel.
  ///
  /// In en, this message translates to:
  /// **'Frame Extraction'**
  String get frameExtractionLabel;

  /// No description provided for @frameExtractionDesc.
  ///
  /// In en, this message translates to:
  /// **'Extracting keyframes using adaptive temporal sampling...'**
  String get frameExtractionDesc;

  /// No description provided for @sceneDetectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Scene Detection'**
  String get sceneDetectionLabel;

  /// No description provided for @sceneDetectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Partitioning video into dynamic visual scenes and cuts...'**
  String get sceneDetectionDesc;

  /// No description provided for @faceDetectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Face Detection'**
  String get faceDetectionLabel;

  /// No description provided for @faceDetectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Running RetinaFace / SCRFD face locator cascade...'**
  String get faceDetectionDesc;

  /// No description provided for @faceTrackingLabel.
  ///
  /// In en, this message translates to:
  /// **'Face Tracking'**
  String get faceTrackingLabel;

  /// No description provided for @faceTrackingDesc.
  ///
  /// In en, this message translates to:
  /// **'Tracking facial bounding boxes across continuous frames...'**
  String get faceTrackingDesc;

  /// No description provided for @qualityAssessmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Quality Assessment'**
  String get qualityAssessmentLabel;

  /// No description provided for @qualityAssessmentDesc.
  ///
  /// In en, this message translates to:
  /// **'Evaluating frame resolution, blur, compression, and lighting...'**
  String get qualityAssessmentDesc;

  /// No description provided for @artifactDetectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Artifact Detection'**
  String get artifactDetectionLabel;

  /// No description provided for @artifactDetectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Searching for facial boundary glitches and warping artifacts...'**
  String get artifactDetectionDesc;

  /// No description provided for @deepfakeAiModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Deepfake AI Model'**
  String get deepfakeAiModelLabel;

  /// No description provided for @deepfakeAiModelDesc.
  ///
  /// In en, this message translates to:
  /// **'Executing EfficientViT TFLite neural inference engine...'**
  String get deepfakeAiModelDesc;

  /// No description provided for @temporalConsistencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Temporal Consistency'**
  String get temporalConsistencyLabel;

  /// No description provided for @temporalConsistencyDesc.
  ///
  /// In en, this message translates to:
  /// **'Evaluating frame-to-frame feature persistence and jitter...'**
  String get temporalConsistencyDesc;

  /// No description provided for @confidenceCalibrationLabel.
  ///
  /// In en, this message translates to:
  /// **'Confidence Calibration'**
  String get confidenceCalibrationLabel;

  /// No description provided for @confidenceCalibrationDesc.
  ///
  /// In en, this message translates to:
  /// **'Applying Temperature Scaling (T=1.5) probability smoothing...'**
  String get confidenceCalibrationDesc;

  /// No description provided for @evidenceAggregationLabel.
  ///
  /// In en, this message translates to:
  /// **'Evidence Aggregation'**
  String get evidenceAggregationLabel;

  /// No description provided for @evidenceAggregationDesc.
  ///
  /// In en, this message translates to:
  /// **'Correlating neural predictions with forensic spatial heuristic data...'**
  String get evidenceAggregationDesc;

  /// No description provided for @riskScoringLabel.
  ///
  /// In en, this message translates to:
  /// **'Risk Scoring'**
  String get riskScoringLabel;

  /// No description provided for @riskScoringDesc.
  ///
  /// In en, this message translates to:
  /// **'Computing multi-factor threat assessment and risk matrix...'**
  String get riskScoringDesc;

  /// No description provided for @finalDecisionLabel.
  ///
  /// In en, this message translates to:
  /// **'Final Decision'**
  String get finalDecisionLabel;

  /// No description provided for @finalDecisionDesc.
  ///
  /// In en, this message translates to:
  /// **'Synthesizing adaptive ensemble verdict...'**
  String get finalDecisionDesc;

  /// No description provided for @generatingReportLabel.
  ///
  /// In en, this message translates to:
  /// **'Generating Report'**
  String get generatingReportLabel;

  /// No description provided for @generatingReportDesc.
  ///
  /// In en, this message translates to:
  /// **'Assembling complete forensic verification report...'**
  String get generatingReportDesc;

  /// No description provided for @verifyNoVideoSelected.
  ///
  /// In en, this message translates to:
  /// **'No video file selected. Please pick a video first.'**
  String get verifyNoVideoSelected;

  /// No description provided for @verifyFrameExtractionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not extract any frames from the video. It may be corrupt or use an unsupported codec.'**
  String get verifyFrameExtractionFailed;

  /// No description provided for @verifyOfflineLinkVerification.
  ///
  /// In en, this message translates to:
  /// **'Running offline link verification...'**
  String get verifyOfflineLinkVerification;

  /// No description provided for @verifyExtractingFramesServer.
  ///
  /// In en, this message translates to:
  /// **'Extracting frames on server...'**
  String get verifyExtractingFramesServer;

  /// No description provided for @verifyDownloadingMediaStream.
  ///
  /// In en, this message translates to:
  /// **'Downloading media stream...'**
  String get verifyDownloadingMediaStream;

  /// No description provided for @verifyExtractingFaceCrops.
  ///
  /// In en, this message translates to:
  /// **'Extracting face crops...'**
  String get verifyExtractingFaceCrops;

  /// No description provided for @verifyLocatingBiometricPoints.
  ///
  /// In en, this message translates to:
  /// **'Locating biometric points...'**
  String get verifyLocatingBiometricPoints;

  /// No description provided for @verifyRunningDeepLearningClassifiers.
  ///
  /// In en, this message translates to:
  /// **'Running deep learning classifiers...'**
  String get verifyRunningDeepLearningClassifiers;

  /// No description provided for @verifyLinkAnalysisEmptyResults.
  ///
  /// In en, this message translates to:
  /// **'Link analysis returned empty results.'**
  String get verifyLinkAnalysisEmptyResults;

  /// No description provided for @verifyForensicServerFailed.
  ///
  /// In en, this message translates to:
  /// **'Forensic server failed to process link.'**
  String get verifyForensicServerFailed;

  /// No description provided for @verifyLiveCameraStream.
  ///
  /// In en, this message translates to:
  /// **'Live Camera Stream'**
  String get verifyLiveCameraStream;

  /// No description provided for @verifyLiveStreamSession.
  ///
  /// In en, this message translates to:
  /// **'Live Stream Session'**
  String get verifyLiveStreamSession;

  /// No description provided for @verifySavingToDatabase.
  ///
  /// In en, this message translates to:
  /// **'Saving to forensic database...'**
  String get verifySavingToDatabase;

  /// No description provided for @verifySendingNotification.
  ///
  /// In en, this message translates to:
  /// **'Sending Notification...'**
  String get verifySendingNotification;

  /// No description provided for @verifyAnalysisCompleteNotification.
  ///
  /// In en, this message translates to:
  /// **'Analysis complete. Verdict: {verdict}. {score}% {type}. Tap to view report.'**
  String verifyAnalysisCompleteNotification(
    Object score,
    Object type,
    Object verdict,
  );

  /// No description provided for @verifyCompletedStatus.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get verifyCompletedStatus;

  /// No description provided for @verifyConfigureConnectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Configure connection settings'**
  String get verifyConfigureConnectionSettings;

  /// No description provided for @notificationsDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete notifications: {error}'**
  String notificationsDeleteFailed(Object error);

  /// No description provided for @profileFailedToPickImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick image'**
  String get profileFailedToPickImage;

  /// No description provided for @profileUserNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'User not authenticated'**
  String get profileUserNotAuthenticated;

  /// No description provided for @profilePasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password should be at least 6 characters'**
  String get profilePasswordTooShort;

  /// No description provided for @profilePasswordUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully!'**
  String get profilePasswordUpdatedSuccessfully;

  /// No description provided for @profilePleaseLoginAgain.
  ///
  /// In en, this message translates to:
  /// **'Please log in again to update your account'**
  String get profilePleaseLoginAgain;

  /// No description provided for @profilePasswordTooWeak.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak'**
  String get profilePasswordTooWeak;

  /// No description provided for @profilePasswordUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update password'**
  String get profilePasswordUpdateFailed;

  /// No description provided for @profileSaveChangesFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save changes'**
  String get profileSaveChangesFailed;

  /// No description provided for @searchHintExample.
  ///
  /// In en, this message translates to:
  /// **'e.g., 945061685V'**
  String get searchHintExample;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Logout'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logoutConfirmMessage;

  /// No description provided for @logoutCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get logoutCancel;

  /// No description provided for @logoutButton.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutButton;

  /// No description provided for @escalateReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Escalate Report'**
  String get escalateReportTitle;

  /// No description provided for @escalateReportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Forward this finding to a national authority'**
  String get escalateReportSubtitle;

  /// No description provided for @authoritySectionLabel.
  ///
  /// In en, this message translates to:
  /// **'AUTHORITY'**
  String get authoritySectionLabel;

  /// No description provided for @sendViaLabel.
  ///
  /// In en, this message translates to:
  /// **'SEND VIA'**
  String get sendViaLabel;

  /// No description provided for @slThreatRadarTitle.
  ///
  /// In en, this message translates to:
  /// **'SL Threat Intelligence Radar'**
  String get slThreatRadarTitle;

  /// No description provided for @slThreatRadarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track viral deepfake scams & voice clones circulating in Sri Lanka.'**
  String get slThreatRadarSubtitle;

  /// No description provided for @slThreatRadarLiveSoon.
  ///
  /// In en, this message translates to:
  /// **'LIVE monitoring coming soon'**
  String get slThreatRadarLiveSoon;

  /// No description provided for @loadingFinishingVerification.
  ///
  /// In en, this message translates to:
  /// **'Finishing verification...'**
  String get loadingFinishingVerification;

  /// No description provided for @loadingEstimatedTime.
  ///
  /// In en, this message translates to:
  /// **'Est. ~{seconds} sec remaining'**
  String loadingEstimatedTime(Object seconds);

  /// No description provided for @cancelAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Cancel Analysis'**
  String get cancelAnalysis;

  /// No description provided for @errorAnalysisInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Analysis Interrupted'**
  String get errorAnalysisInterrupted;

  /// No description provided for @errorOfflineTFLiteAvailable.
  ///
  /// In en, this message translates to:
  /// **'Offline TFLite Fallback Available'**
  String get errorOfflineTFLiteAvailable;

  /// No description provided for @errorWhatHappened.
  ///
  /// In en, this message translates to:
  /// **'What happened'**
  String get errorWhatHappened;

  /// No description provided for @errorPossibleReason.
  ///
  /// In en, this message translates to:
  /// **'Possible reason'**
  String get errorPossibleReason;

  /// No description provided for @errorRetryAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Retry Analysis'**
  String get errorRetryAnalysis;

  /// No description provided for @errorContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get errorContactSupport;

  /// No description provided for @errorOopsTitle.
  ///
  /// In en, this message translates to:
  /// **'Oops! Something went wrong'**
  String get errorOopsTitle;

  /// No description provided for @errorTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get errorTryAgain;

  /// No description provided for @emptyNoReports.
  ///
  /// In en, this message translates to:
  /// **'No Verification Reports'**
  String get emptyNoReports;

  /// No description provided for @emptyNoNotifications.
  ///
  /// In en, this message translates to:
  /// **'No Notifications Yet'**
  String get emptyNoNotifications;

  /// No description provided for @emptyNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No History Available'**
  String get emptyNoHistory;

  /// No description provided for @emptyNoSearches.
  ///
  /// In en, this message translates to:
  /// **'No Searches Found'**
  String get emptyNoSearches;

  /// No description provided for @emptyNoResults.
  ///
  /// In en, this message translates to:
  /// **'No Analysis Results'**
  String get emptyNoResults;

  /// No description provided for @emptyNoReportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload a video or image link to generate your first AI deepfake forensic report.'**
  String get emptyNoReportsSubtitle;

  /// No description provided for @emptyNoNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You are all caught up! New forensic alerts will appear here.'**
  String get emptyNoNotificationsSubtitle;

  /// No description provided for @emptyNoHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Completed media analysis records will be stored securely in your history.'**
  String get emptyNoHistorySubtitle;

  /// No description provided for @emptyNoSearchesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search criteria or keywords to find matching records.'**
  String get emptyNoSearchesSubtitle;

  /// No description provided for @emptyNoResultsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Run a verification task to display detailed deepfake metrics and evidence.'**
  String get emptyNoResultsSubtitle;

  /// No description provided for @backTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backTooltip;

  /// No description provided for @changeLanguageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get changeLanguageTooltip;

  /// No description provided for @lightModeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch to Light Mode'**
  String get lightModeTooltip;

  /// No description provided for @darkModeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch to Dark Mode'**
  String get darkModeTooltip;

  /// No description provided for @notificationsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTooltip;

  /// No description provided for @formTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff Affirmation Form'**
  String get formTitle;

  /// No description provided for @selectOption.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get selectOption;

  /// No description provided for @submitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get submitting;

  /// No description provided for @errorSaving.
  ///
  /// In en, this message translates to:
  /// **'Error saving data. Please try again.'**
  String get errorSaving;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error. Please check your internet connection.'**
  String get connectionError;

  /// No description provided for @loginRequired.
  ///
  /// In en, this message translates to:
  /// **'You must be logged in to submit this form.'**
  String get loginRequired;

  /// No description provided for @datesSectionHint.
  ///
  /// In en, this message translates to:
  /// **'Use YYYY-MM-DD format for all dates'**
  String get datesSectionHint;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfileTitle;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileName;

  /// No description provided for @profileEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmail;

  /// No description provided for @profileNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get profileNewPassword;

  /// No description provided for @profileConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get profileConfirmPassword;

  /// No description provided for @profilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Profile Photo'**
  String get profilePhoto;

  /// No description provided for @profileChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change Photo'**
  String get profileChangePhoto;

  /// No description provided for @profileRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove Photo'**
  String get profileRemovePhoto;

  /// No description provided for @profilePasswordChange.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get profilePasswordChange;

  /// No description provided for @profileCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get profileCurrentPassword;

  /// No description provided for @profileSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave;

  /// No description provided for @profileCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancel;

  /// No description provided for @profileUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get profileUploading;

  /// No description provided for @profileImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image size should be less than 5MB'**
  String get profileImageTooLarge;

  /// No description provided for @reportShareReport.
  ///
  /// In en, this message translates to:
  /// **'Share Report'**
  String get reportShareReport;

  /// No description provided for @reportShareVia.
  ///
  /// In en, this message translates to:
  /// **'Share via'**
  String get reportShareVia;

  /// No description provided for @reportShareLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Link'**
  String get reportShareLink;

  /// No description provided for @reportSharePdf.
  ///
  /// In en, this message translates to:
  /// **'Share PDF'**
  String get reportSharePdf;

  /// No description provided for @reportShareImage.
  ///
  /// In en, this message translates to:
  /// **'Share Image'**
  String get reportShareImage;

  /// No description provided for @reportCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Report link copied to clipboard.'**
  String get reportCopiedToClipboard;

  /// No description provided for @reportShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to share report'**
  String get reportShareFailed;
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
    'that was used.',
  );
}
