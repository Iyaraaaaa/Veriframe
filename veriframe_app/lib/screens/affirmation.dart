import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';

class AffirmationForm extends StatefulWidget {
  const AffirmationForm({Key? key}) : super(key: key);

  @override
  State<AffirmationForm> createState() => _AffirmationFormState();
}

class _AffirmationFormState extends State<AffirmationForm> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Controllers for text inputs
  final _incidentIdController = TextEditingController();
  final _reporterNameController = TextEditingController();
  final _nicController = TextEditingController();
  final _evidenceReferenceController = TextEditingController();
  
  // Form data variables
  DateTime? _incidentDate;
  DateTime? _dateDetected;
  DateTime? _defNotifyDate;
  DateTime? _resolutionDate;
  DateTime? _sentDate;
  DateTime? _reviewDate;
  DateTime? _closureDate;
  
  String? _selectedDesignation;
  String? _selectedStation;
  String? _selectedResponsibleOfficer;
  
  // UI State
  bool _isSubmitting = false;
  bool _isDarkMode = false;
  String _currentLanguage = 'en';
  
  // Language translations
  final Map<String, Map<String, String>> _translations = {
    'en': {
      'formTitle': 'Staff Affirmation Form',
      'incidentId': 'Incident ID',
      'incidentDate': 'Incident Date (YY-MM-DD)',
      'reporterName': 'Reporter Name',
      'badgeNumber': 'Badge Number',
      'threatLevel': 'Designation',
      'targetPlatform': 'Target Platform',
      'dateDetected': 'Date Detected (YYYY-MM-DD)',
      'assignedInvestigator': 'Assigned Investigator',
      'evidenceReference': 'Evidence Reference',
      'escalationDate': 'Escalation Date (YY-MM-DD)',
      'resolutionDate': 'Resolution Date (YY-MM-DD)',
      'lawEnforcementDate': 'Law Enforcement Notified Date (YY-MM-DD)',
      'reviewDate': 'Review Date (YY-MM-DD)',
      'closureDate': 'Closure Date (YY-MM-DD)',
      'submitForm': 'Submit Form',
      'requiredField': 'This field is required',
      'selectDate': 'Please select a date',
      'pleaseSelect': 'Please select an option',
      'success': 'Success',
      'formSubmittedSuccess': 'Form Submitted Successfully!',
      'ok': 'OK',
      'selectOption': 'Select',
      'submitting': 'Submitting...',
      'errorSaving': 'Error saving data. Please try again.',
      'connectionError': 'Connection error. Please check your internet connection.',
      'loginRequired': 'You must be logged in to submit this form.',
    },
    'si': {
      'formTitle': 'කාර්ය මණ්ඩල තහවුරු කිරීමේ පෝරමය',
      'incidentId': 'අනු අංකය',
      'incidentDate': 'ලිපිය ලද දිනය (YY-MM-DD)',
      'reporterName': 'නිලධාරියාගේ නම',
      'badgeNumber': 'ජාතික හැඳුනුම්පත් අංකය',
      'threatLevel': 'තනතුර',
      'targetPlatform': 'සේවා ස්ථානය',
      'dateDetected': 'ස්ථිර කළ යුතු දිනය (YYYY-MM-DD)',
      'assignedInvestigator': 'විෂය භාර නිලධාරී',
      'evidenceReference': 'ගොනු අංකය',
      'escalationDate': 'අඩුපාඩු දැනුම් දුන් දිනය (YY-MM-DD)',
      'resolutionDate': 'අඩුපාඩු නිවැරදි කර එවූ දිනය (YY-MM-DD)',
      'lawEnforcementDate': 'PPSC/ප්‍රධාන ලේකම් යැවූ දිනය (YY-MM-DD)',
      'reviewDate': 'අනුමැතිය ලද දිනය (YY-MM-DD)',
      'closureDate': 'අනුමැතිය දැනුම් දුන් දිනය (YY-MM-DD)',
      'submitForm': 'පෝරමය ඉදිරිපත් කරන්න',
      'requiredField': 'මෙම ක්ෂේත්‍රය අවශ්‍ය වේ',
      'selectDate': 'කරුණාකර දිනයක් තෝරන්න',
      'pleaseSelect': 'කරුණාකර විකල්පයක් තෝරන්න',
      'success': 'සාර්ථකයි',
      'formSubmittedSuccess': 'පෝරමය සාර්ථකව ඉදිරිපත් කරන ලදී!',
      'ok': 'හරි',
      'selectOption': 'තෝරන්න',
      'submitting': 'ඉදිරිපත් කරමින්...',
      'errorSaving': 'දත්ත සුරැකීමේ දෝෂයකි. කරුණාකර නැවත උත්සාහ කරන්න.',
      'connectionError': 'සම්බන්ධතා දෝෂයකි. කරුණාකර ඔබේ අන්තර්ජාල සම්බන්ධතාව පරීක්ෂා කරන්න.',
      'loginRequired': 'මෙම පෝරමය ඉදිරිපත් කිරීමට ඔබ ලොග් වී සිටිය යුතුයි.',
    },
    'ta': {
      'formTitle': 'ஊழியர் உறுதிப்படுத்தல் படிவம்',
      'incidentId': 'வரிசை எண்',
      'incidentDate': 'கடித தேதி (YY-MM-DD)',
      'reporterName': 'அதிகாரியின் பெயர்',
      'badgeNumber': 'தேசிய அடையாள அட்டை எண்',
      'threatLevel': 'பதவி',
      'targetPlatform': 'சேவை நிலையம்',
      'dateDetected': 'உறுதிசெய்த தேதி (YYYY-MM-DD)',
      'assignedInvestigator': 'பொறுப்பு அதிகாரி',
      'evidenceReference': 'கோப்பு எண்',
      'escalationDate': 'குறைபாடு அறிவிக்கப்பட்ட தேதி (YY-MM-DD)',
      'resolutionDate': 'குறைபாடு சரிசெய்யப்பட்ட தேதி (YY-MM-DD)',
      'lawEnforcementDate': 'PPSC/முதலமைச்சருக்கு அனுப்பிய தேதி (YY-MM-DD)',
      'reviewDate': 'அனுமதி வழங்கிய தேதி (YY-MM-DD)',
      'closureDate': 'அனுமதி அறிவிக்கப்பட்ட தேதி (YY-MM-DD)',
      'submitForm': 'படிவத்தை சமர்ப்பிக்கவும்',
      'requiredField': 'இந்த புலம் தேவை',
      'selectDate': 'தயவுசெய்து தேதியைத் தேர்ந்தெடுக்கவும்',
      'pleaseSelect': 'தயவுசெய்து ஒரு விருப்பத்தைத் தேர்ந்தெடுக்கவும்',
      'success': 'வெற்றி',
      'formSubmittedSuccess': 'படிவம் வெற்றிகரமாக சமர்ப்பிக்கப்பட்டது!',
      'ok': 'சரி',
      'selectOption': 'தேர்ந்தெடுக்கவும்',
      'submitting': 'சமர்ப்பிக்கிறது...',
      'errorSaving': 'தரவு சேமிப்பதில் பிழை. மீண்டும் முயற்சி செய்யவும்.',
      'connectionError': 'இணைப்பு பிழை. உங்கள் இணைய இணைப்பைச் சரிபார்க்கவும்.',
      'loginRequired': 'இந்த படிவத்தை சமர்ப்பிக்க நீங்கள் உள்நுழைந்திருக்க வேண்டும்.',
    },
  };

  // Dropdown options
  final Map<String, List<String>> _threatLevelsTranslated = {
    'en': [
      'Health Technical Officer (Junior)',
      'Health Technical Officer (General)',
      'Nursing Assistant / Support Staff',
      'Store Keeper',
      'Plumber',
      'Medical Supply Assistant',
      'Driver',
      'Mason',
      'Laboratory Attendant',
      'Threat Assessment Inspector (PHI)',
      'Medical Laboratory Technologist',
      'Pharmacist',
      'Medical Superintendent',
      'Nurse',
      'Minor Service Supervisor',
      'Administrative Clerk',
      'Development Officer',
      'Electrician',
      'Elevator Operator',
      'Management Service Officer',
      'Ward Clerk'
    ],
    'si': [
      'සෞඛ්‍ය තාක්ෂණික නිලධාරියා (කනිෂ්ඨ)',
      'සෞඛ්‍ය තාක්ෂණික නිලධාරියා (සාමාන්‍ය)',
      'හෙද සහායක / ආධාරක කාර්ය මණ්ඩලය',
      'ගබඩා රැකවරු',
      'ජල නළ කාර්මිකයා',
      'වෛද්‍ය සැපයුම් සහායක',
      'රියදුරු',
      'පෙදරේරු',
      'පරීක්ෂාගාර සේවක',
      'මහජන සෞඛ්‍ය පරීක්ෂක (PHI)',
      'වෛද්‍ය පරීක්ෂාගාර තාක්ෂණ විදයාඥ',
      'ඖෂධවේදියා',
      'වෛද්‍ය අධිකාරී',
      'හෙදිය',
      'සුළු සේවා අධීක්ෂක',
      'පරිපාලන ලිපිකරු',
      'සංවර්ධන නිලධාරියා',
      'විදුලි කාර්මිකයා',
      'සෝපාන යන්ත්‍ර ක්‍රියාකරු',
      'කළමනාකරණ සේවා නිලධාරියා',
      'වාට ලිපිකරු'
    ],
    'ta': [
      'சுகாதார தொழில்நுட்ப அதிகாரி (கனிஷ்டர்)',
      'சுகாதார தொழில்நுட்ப அதிகாரி (பொது)',
      'நர்சிங் உதவியாளர் / ஆதரவு ஊழியர்கள்',
      'கிடங்கு காப்பாளர்',
      'குழாய் தொழிலாளி',
      'மருத்துவ வழங்கல் உதவியாளர்',
      'ஓட்டுநர்',
      'கட்டிட தொழிலாளி',
      'ஆய்வகம் பணியாளர்',
      'பொது சுகாதார ஆய்வாளர் (PHI)',
      'மருத்துவ ஆய்வக தொழில்நுட்ப வல்லுநர்',
      'மருந்தாளர்',
      'மருத்துவ மேற்பார்வையாளர்',
      'நர்ஸ்',
      'சிறு சேவை மேற்பார்வையாளர்',
      'நிர்வாக எழுத்தர்',
      'வளர்ச்சி அதிகாரி',
      'மின்சார தொழிலாளி',
      'லிஃப்ட் ஆபரேட்டர்',
      'நிர்வாக சேவை அதிகாரி',
      'வார்டு எழுத்தர்'
    ]
  };

  final Map<String, List<String>> _stationsTranslated = {
    'en': [
      'Base Hospital - Kiribathgoda',
      'Kethumathi Hospital - Panadura',
      'Base Hospital - Panadura',
      'District General Hospital - Horana',
      'Base Hospital - Wattupitiwala',
      'Threat Assessment Inspector Office - Moratuwa',
      'Divisional Hospital - Galpotha',
      'Divisional Hospital - Baduraliya',
      'District Hospital - Ingiriya',
      'Base Hospital - Minuwangoda',
      'Base Hospital - Mirigama',
      'District General Hospital - Gampaha',
      'Medical Supplies Division - Bellapitiya',
      'STD Control Clinic - Meegamuwa',
      'Regional Medical Supply Unit - Ragama',
      'Public Dispensary - Anuragoda',
      'Regional Forensic Services Division - Kalutara'
    ],
    'si': [
      'මූලික රෝහල - කිරිබත්ගොඩ',
      'කේතුමති රෝහල - පානදුර',
      'මූලික රෝහල - පානදුර',
      'දිස්ත්‍රික් මහ රෝහල - හොරණ',
      'මූලික රෝහල - වට්ටුපිටිවල',
      'මහජන සෞඛ්‍ය පරීක්ෂක කාර්යාලය - මොරටුව',
      'කොට්ඨාශ රෝහල - ගල්පොත',
      'කොට්ඨාශ රෝහල - බදුරලිය',
      'දිස්ත්‍රික් රෝහල - ඉඟිරිය',
      'මූලික රෝහල - මිණුවන්ගොඩ',
      'මූලික රෝහල - මීරිගම',
      'දිස්ත්‍රික් මහ රෝහල - ගම්පහ',
      'වෛද්‍ය සැපයුම් අංශය - බැල්ලපිටිය',
      'STD පාලන සායනය - මීගමුව',
      'ප්‍රාදේශීය වෛද්‍ය සැපයුම් ඒකකය - රාගම',
      'මහජන ඔසුසල - අනුරාගොඩ',
      'ප්‍රාදේශීය සෞඛ්‍ය සේවා අංශය - කළුතර'
    ],
    'ta': [
      'அடிப்படை மருத்துவமனை - கிரிபத்கொடை',
      'கேதுமதி மருத்துவமனை - பனடுர',
      'அடிப்படை மருத்துவமனை - பனடுர',
      'மாவட்ட பொது மருத்துவமனை - ஹோரன',
      'அடிப்படை மருத்துவமனை - வத்துபிடிவல',
      'பொது சுகாதார ஆய்வாளர் அலுவலகம் - மொரட்டுவ',
      'பிரிவு மருத்துவமனை - கல்போத',
      'பிரிவு மருத்துவமனை - பதுரலிய',
      'மாவட்ட மருத்துவமனை - இங்கிரிய',
      'அடிப்படை மருத்துவமனை - மினுவங்கொடை',
      'அடிப்படை மருத்துவமனை - மீரிகம',
      'மாவட்ட பொது மருத்துவமனை - கம்பஹ',
      'மருத்துவ வழங்கல் பிரிவு - பெல்லபிட்டிய',
      'STD கட்டுப்பாட்டு நிலையம் - மீகமுவ',
      'பிராந்திய மருத்துவ வழங்கல் அலகு - ரகம',
      'பொது மருந்தகம் - அனுரகொடை',
      'பிராந்திய சுகாதார சேவைகள் பிரிவு - கலுதர'
    ]
  };

  final List<String> _assignedInvestigators = ['A05', 'A17', 'A14', 'A11', 'A02'];

  @override
  void dispose() {
    _incidentIdController.dispose();
    _reporterNameController.dispose();
    _nicController.dispose();
    _evidenceReferenceController.dispose();
    super.dispose();
  }

  String _getTranslation(String key) {
    return _translations[_currentLanguage]?[key] ?? _translations['en']![key]!;
  }

  List<String> _getDesignations() {
    return _threatLevelsTranslated[_currentLanguage] ?? _threatLevelsTranslated['en']!;
  }

  List<String> _getStations() {
    return _stationsTranslated[_currentLanguage] ?? _stationsTranslated['en']!;
  }

  Future<void> _selectDate(BuildContext context, String field) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: _isDarkMode
                ? const ColorScheme.dark(primary: Color(0xFF4DB6AC))
                : const ColorScheme.light(primary: Color(0xFF009688)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        switch (field) {
          case 'incidentDate':
            _incidentDate = picked;
            break;
          case 'dateDetected':
            _dateDetected = picked;
            break;
          case 'defNotifyDate':
            _defNotifyDate = picked;
            break;
          case 'resolutionDate':
            _resolutionDate = picked;
            break;
          case 'sentDate':
            _sentDate = picked;
            break;
          case 'reviewDate':
            _reviewDate = picked;
            break;
          case 'closureDate':
            _closureDate = picked;
            break;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    // Check required fields
    if (_incidentDate == null || _dateDetected == null) {
      _showErrorSnackBar(_getTranslation('selectDate'));
      return false;
    }

    if (_selectedDesignation == null || 
        _selectedStation == null || 
        _selectedResponsibleOfficer == null) {
      _showErrorSnackBar(_getTranslation('pleaseSelect'));
      return false;
    }

    return true;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
          title: Text(
            '🎉 ${_getTranslation('success')}',
            style: TextStyle(
              color: _isDarkMode ? const Color(0xFFE0E0E0) : const Color(0xFF333333),
            ),
          ),
          content: Text(
            _getTranslation('formSubmittedSuccess'),
            style: TextStyle(
              color: _isDarkMode ? const Color(0xFFCBD5E1) : const Color(0xFF555555),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetForm();
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF009688),
                foregroundColor: Colors.white,
              ),
              child: Text(_getTranslation('ok')),
            ),
          ],
        );
      },
    );
  }

  void _resetForm() {
    setState(() {
      _incidentIdController.clear();
      _reporterNameController.clear();
      _nicController.clear();
      _evidenceReferenceController.clear();
      _incidentDate = null;
      _dateDetected = null;
      _defNotifyDate = null;
      _resolutionDate = null;
      _sentDate = null;
      _reviewDate = null;
      _closureDate = null;
      _selectedDesignation = null;
      _selectedStation = null;
      _selectedResponsibleOfficer = null;
    });
  }

  Future<void> _submitForm() async {
    if (!_validateForm()) return;

    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      _showErrorSnackBar(_getTranslation('loginRequired'));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final Map<String, dynamic> formData = {
        'incidentId': _incidentIdController.text,
        'incidentDate': _formatDate(_incidentDate),
        'reporterName': _reporterNameController.text,
        'nic': _nicController.text,
        'threatLevel': _selectedDesignation,
        'station': _selectedStation,
        'dateDetected': _formatDate(_dateDetected),
        'assignedInvestigator': _selectedResponsibleOfficer,
        'evidenceReference': _evidenceReferenceController.text,
        'userId': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'submittedBy': currentUser.email ?? 'user',
        'status': 'submitted',
        'language': _currentLanguage,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Add optional fields if they have values
      if (_defNotifyDate != null) {
        formData['defNotifyDate'] = _formatDate(_defNotifyDate);
      }
      if (_resolutionDate != null) {
        formData['resolutionDate'] = _formatDate(_resolutionDate);
      }
      if (_sentDate != null) {
        formData['sentDate'] = _formatDate(_sentDate);
      }
      if (_reviewDate != null) {
        formData['reviewDate'] = _formatDate(_reviewDate);
      }
      if (_closureDate != null) {
        formData['closureDate'] = _formatDate(_closureDate);
      }

      await _firestore.collection('affirmations').add(formData);
      _showSuccessDialog();
    } catch (e) {
      print('Error submitting form: $e');
      String errorMessage = _getTranslation('errorSaving');
      
      if (e.toString().contains('network')) {
        errorMessage = _getTranslation('connectionError');
      }
      
      _showErrorSnackBar(errorMessage);
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _isDarkMode = theme.brightness == Brightness.dark;

    return MainScaffold(
      showBack: true,
      title: Text(_getTranslation('formTitle')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Card(
              color: _isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📋 ${_getTranslation('formTitle')}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode ? const Color(0xFF4DB6AC) : const Color(0xFF009688),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      
                      // 1. Incident ID
                      _buildTextFormField(
                        controller: _incidentIdController,
                        labelText: _getTranslation('incidentId'),
                        isRequired: true,
                      ),
                      
                      // 2. Incident Date
                      _buildDateFormField(
                        labelText: _getTranslation('incidentDate'),
                        date: _incidentDate,
                        onTap: () => _selectDate(context, 'incidentDate'),
                        isRequired: true,
                      ),
                      
                      // 3. Reporter Name
                      _buildTextFormField(
                        controller: _reporterNameController,
                        labelText: _getTranslation('reporterName'),
                        isRequired: true,
                      ),
                      
                      // 4. Badge Number
                      _buildTextFormField(
                        controller: _nicController,
                        labelText: _getTranslation('badgeNumber'),
                        isRequired: true,
                      ),
                      
                      // 5. Designation
                      _buildDropdownFormField(
                        labelText: _getTranslation('threatLevel'),
                        value: _selectedDesignation,
                        items: _getDesignations(),
                        onChanged: (value) => setState(() => _selectedDesignation = value),
                        isRequired: true,
                      ),
                      
                      // 6. Target Platform
                      _buildDropdownFormField(
                        labelText: _getTranslation('targetPlatform'),
                        value: _selectedStation,
                        items: _getStations(),
                        onChanged: (value) => setState(() => _selectedStation = value),
                        isRequired: true,
                      ),
                      
                      // 7. Date Detected
                      _buildDateFormField(
                        labelText: _getTranslation('dateDetected'),
                        date: _dateDetected,
                        onTap: () => _selectDate(context, 'dateDetected'),
                        isRequired: true,
                      ),
                      
                      // 8. Assigned Investigator
                      _buildDropdownFormField(
                        labelText: _getTranslation('assignedInvestigator'),
                        value: _selectedResponsibleOfficer,
                        items: _assignedInvestigators,
                        onChanged: (value) => setState(() => _selectedResponsibleOfficer = value),
                        isRequired: true,
                      ),
                      
                      // 9. Evidence Reference
                      _buildTextFormField(
                        controller: _evidenceReferenceController,
                        labelText: _getTranslation('evidenceReference'),
                        isRequired: true,
                      ),
                      
                      // 10. Escalation Date
                      _buildDateFormField(
                        labelText: _getTranslation('escalationDate'),
                        date: _defNotifyDate,
                        onTap: () => _selectDate(context, 'defNotifyDate'),
                        isRequired: false,
                      ),
                      
                      // 11. Resolution Date
                      _buildDateFormField(
                        labelText: _getTranslation('resolutionDate'),
                        date: _resolutionDate,
                        onTap: () => _selectDate(context, 'resolutionDate'),
                        isRequired: false,
                      ),
                      
                      // 12. Law Enforcement Notified Date
                      _buildDateFormField(
                        labelText: _getTranslation('lawEnforcementDate'),
                        date: _sentDate,
                        onTap: () => _selectDate(context, 'sentDate'),
                        isRequired: false,
                      ),
                      
                      // 13. Review Date
                      _buildDateFormField(
                        labelText: _getTranslation('reviewDate'),
                        date: _reviewDate,
                        onTap: () => _selectDate(context, 'reviewDate'),
                        isRequired: false,
                      ),
                      
                      // 14. Closure Date
                      _buildDateFormField(
                        labelText: _getTranslation('closureDate'),
                        date: _closureDate,
                        onTap: () => _selectDate(context, 'closureDate'),
                        isRequired: false,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isSubmitting ? Colors.grey : const Color(0xFF009688),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            _isSubmitting 
                                ? '⏳ ${_getTranslation('submitting')}'
                                : '📤 ${_getTranslation('submitForm')}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(
          color: _isDarkMode ? Colors.white : Colors.black,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(
            color: _isDarkMode ? const Color(0xFFE0E0E0) : const Color(0xFF333333),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: _isDarkMode ? const Color(0xFF555555) : const Color(0xFFDDDDDD),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: _isDarkMode ? const Color(0xFF555555) : const Color(0xFFDDDDDD),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Color(0xFF009688),
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 1,
            ),
          ),
          filled: true,
          fillColor: _isDarkMode ? const Color(0xFF424242) : Colors.white,
          contentPadding: const EdgeInsets.all(12),
        ),
        validator: isRequired ? (value) {
          if (value == null || value.isEmpty) {
            return _getTranslation('requiredField');
          }
          return null;
        } : null,
      ),
    );
  }

  Widget _buildDateFormField({
    required String labelText,
    required DateTime? date,
    required VoidCallback onTap,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: labelText,
            labelStyle: TextStyle(
              color: _isDarkMode ? const Color(0xFFE0E0E0) : const Color(0xFF333333),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _isDarkMode ? const Color(0xFF555555) : const Color(0xFFDDDDDD),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _isDarkMode ? const Color(0xFF555555) : const Color(0xFFDDDDDD),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFF009688),
                width: 2,
              ),
            ),
            filled: true,
            fillColor: _isDarkMode ? const Color(0xFF424242) : Colors.white,
            contentPadding: const EdgeInsets.all(12),
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          child: Text(
            date != null ? _formatDate(date) : _getTranslation('selectDate'),
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownFormField({
    required String labelText,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DropdownButtonFormField<String>(
        value: value,
        onChanged: onChanged,
        style: TextStyle(
          color: _isDarkMode ? Colors.white : Colors.black,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(
            color: _isDarkMode ? const Color(0xFFE0E0E0) : const Color(0xFF333333),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: _isDarkMode ? const Color(0xFF555555) : const Color(0xFFDDDDDD),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: _isDarkMode ? const Color(0xFF555555) : const Color(0xFFDDDDDD),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Color(0xFF009688),
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 1,
            ),
          ),
          filled: true,
          fillColor: _isDarkMode ? const Color(0xFF424242) : Colors.white,
          contentPadding: const EdgeInsets.all(12),
        ),
        dropdownColor: _isDarkMode ? const Color(0xFF424242) : Colors.white,
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(
              '${_getTranslation('selectOption')} $labelText',
              style: TextStyle(
                color: _isDarkMode ? Colors.grey : Colors.grey[600],
              ),
            ),
          ),
          ...items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            );
          }).toList(),
        ],
        validator: isRequired ? (value) {
          if (value == null || value.isEmpty) {
            return _getTranslation('pleaseSelect');
          }
          return null;
        } : null,
      ),
    );
  }
}


