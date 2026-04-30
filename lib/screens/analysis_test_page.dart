import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guidex/app_routes.dart';
import 'package:guidex/models/college_option.dart';
import 'package:guidex/models/recommendation_result.dart';
import 'package:guidex/services/api_service.dart';

class AnalysisTestPage extends StatefulWidget {
  const AnalysisTestPage({super.key});

  @override
  State<AnalysisTestPage> createState() => _AnalysisTestPageState();
}

class _AnalysisTestPageState extends State<AnalysisTestPage> {
  final PageController _pageController = PageController();
  final ApiService _apiService = ApiService();
  int _currentStep = 0;
  bool _isLoading = false;

  // Screen 1 Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  // Screen 1 Focus Nodes & Error State
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _ageFocusNode = FocusNode();
  final FocusNode _mobileFocusNode = FocusNode();
  final Map<String, bool> _fieldErrors = {
    'name': false,
    'age': false,
    'mobile': false,
    'category': false,
  };

  // Screen 2 Controllers
  final TextEditingController _physicsController = TextEditingController();
  final TextEditingController _chemistryController = TextEditingController();
  final TextEditingController _mathsController = TextEditingController();

  // Screen 2 Focus Nodes & Error State
  final FocusNode _physicsFocusNode = FocusNode();
  final FocusNode _chemistryFocusNode = FocusNode();
  final FocusNode _mathsFocusNode = FocusNode();
  final Map<String, bool> _step2FieldErrors = {
    'physics': false,
    'chemistry': false,
    'maths': false,
  };
  double _cutoff = 0.0;
  final List<String> _categories = [
    'OC',
    'BC',
    'BCM',
    'MBC',
    'SC',
    'SCA',
    'ST'
  ];

  // Final Selection Data
  String _selectedCategory = '';
  String _selectedDistrict = 'Any';
  String _selectedInterest = '';
  String _hostelPreference = ''; // 'Yes' or 'No'
  List<String> _assignedDepartments = [];

  // Interest Area to Departments Mapping
  static const Map<String, List<String>> _interestAreaToDepartments = {
    'App Development': ['CSE', 'IT'],
    'Web Development': ['CSE', 'IT'],
    'AI / ML': ['CSE', 'AI&DS'],
    'Data Science': ['CSE', 'AI&DS'],
    'Embedded Systems': ['ECE', 'EEE'],
    'Core Engineering (Mechanical, Civil)': ['ME', 'CE'],
    'Bio/Medical': ['BME'],
  };

  static const List<String> _interestAreaOptions = [
    'App Development',
    'Web Development',
    'AI / ML',
    'Data Science',
    'Embedded Systems',
    'Core Engineering (Mechanical, Civil)',
    'Bio/Medical',
  ];

  final List<String> _fallbackCourses = [
    'Computer Science Engineering',
    'Information Technology',
    'Electronics and Communication Engineering',
    'Electrical and Electronics Engineering',
    'Mechanical Engineering',
    'Civil Engineering',
    'Biomedical Engineering',
  ];
  List<String> _courseOptions = [];
  Map<String, String> _courseDisplayToQuery = {};
  bool _coursesLoading = false;
  bool _collegeOptionsLoading = false;
  List<String> _districtOptions = const ['Any'];
  List<CollegeOption> _selectedPreferredColleges = const [];
  static const int _maxPreferredColleges = 5;
  static const List<String> _fallbackDistricts = [
    'Any',
    'Ariyalur',
    'Chengalpattu',
    'Chennai',
    'Coimbatore',
    'Cuddalore',
    'Dharmapuri',
    'Dindigul',
    'Erode',
    'Kancheepuram',
    'Kanyakumari',
    'Karur',
    'Krishnagiri',
    'Madurai',
    'Nagapattinam',
    'Namakkal',
    'Nilgiris',
    'Perambalur',
    'Pudukkottai',
    'Ramanathapuram',
    'Salem',
    'Sivagangai',
    'Thanjavur',
    'Theni',
    'Thiruvallur',
    'Thiruvannamalai',
    'Thiruvarur',
    'Thoothukudi',
    'Tiruchirappalli',
    'Tirunelveli',
    'Tiruppur',
    'Vellore',
    'Villupuram',
    'Virudhunagar',
  ];

  static const Map<String, String> _courseCodeToFullName = {
    'CS': 'Computer Science Engineering',
    'EC': 'Electronics and Communication Engineering',
    'EE': 'Electrical and Electronics Engineering',
    'EI': 'Electronics and Instrumentation Engineering',
    'CE': 'Civil Engineering',
    'CI': 'Civil Engineering',
    'CL': 'Civil Engineering',
    'AD': 'Artificial Intelligence and Data Science',
    'AM': 'Artificial Intelligence and Machine Learning',
    'CB': 'Computer Science and Business Systems',
    'CD': 'Computer Science and Design',
    'CG': 'Computer Science and Engineering (AI and ML)',
    'CO': 'Computer Science and Engineering (IoT)',
    'CN': 'Computer Science and Engineering (Networks)',
    'CR': 'Computer Science and Engineering (Cyber Security)',
    'CW': 'Computer Science and Engineering (Data Science)',
    'CY': 'Cyber Security',
    'CZ': 'Computer Science and Engineering (Specialization)',
    'SC': 'Computer Science and Engineering (Cyber Security)',
    'AE': 'Aeronautical Engineering',
    'AGE': 'Agricultural Engineering',
    'AG': 'Agricultural Engineering',
    'AI&DS': 'Artificial Intelligence and Data Science',
    'APT': 'Apparel Technology',
    'ARCH': 'Architecture',
    'ASE': 'Aerospace Engineering',
    'AU': 'Automobile Engineering',
    'BME': 'Biomedical Engineering',
    'BT': 'Biotechnology',
    'CCE': 'Computer and Communication Engineering',
    'CECE': 'Civil and Environmental Engineering',
    'CHE': 'Chemical Engineering',
    'CIVIL': 'Civil Engineering',
    'CRT': 'Ceramic Technology',
    'CSBS': 'Computer Science and Business Systems',
    'CSE': 'Computer Science Engineering',
    'CSE (AI&ML)': 'Computer Science Engineering (AI and ML)',
    'CSE (BDA)': 'Computer Science Engineering (Big Data Analytics)',
    'CSE (IOT&CS)': 'Computer Science Engineering (IoT and Cyber Security)',
    'CST': 'Computer Science and Technology',
    'CT': 'Chemical Technology',
    'CYS': 'Cyber Security',
    'ECE': 'Electronics and Communication Engineering',
    'EEE': 'Electrical and Electronics Engineering',
    'EIE': 'Electronics and Instrumentation Engineering',
    'ENVE': 'Environmental Engineering',
    'ETE': 'Electronics and Telecommunication Engineering',
    'FASHT': 'Fashion Technology',
    'FT': 'Food Technology',
    'GI': 'Geo Informatics',
    'HTT': 'Handloom and Textile Technology',
    'IBT': 'Industrial Biotechnology',
    'ICE': 'Instrumentation and Control Engineering',
    'IE': 'Industrial Engineering',
    'IEM': 'Industrial Engineering and Management',
    'ISE': 'Information Science and Engineering',
    'IT': 'Information Technology',
    'LE': 'Leather Technology',
    'MAE': 'Mechanical and Automation Engineering',
    'MCT': 'Mechatronics Engineering',
    'MDE': 'Manufacturing Design Engineering',
    'ME': 'Mechanical Engineering',
    'ME (MFG)': 'Mechanical Engineering (Manufacturing)',
    'MFGE': 'Manufacturing Engineering',
    'MI': 'Mining Engineering',
    'MME': 'Metallurgical and Materials Engineering',
    'MRE': 'Mechatronics and Robotics Engineering',
    'MSE': 'Materials Science and Engineering',
    'MT': 'Marine Technology',
    'PCT': 'Petrochemical Technology',
    'PE': 'Production Engineering',
    'PET': 'Petroleum Engineering and Technology',
    'PETRO': 'Petrochemical Engineering',
    'PETROCHEMICAL E': 'Petrochemical Engineering',
    'PHARMT': 'Pharmaceutical Technology',
    'PH': 'Pharmaceutical Technology',
    'PT': 'Polymer Technology',
    'PP': 'Polymer and Plastics Technology',
    'RA': 'Robotics and Automation',
    'RM': 'Robotics and Automation',
    'RPT': 'Rubber and Plastics Technology',
    'RP': 'Rubber and Plastics Technology',
    'TC': 'Textile Chemistry',
    'TX': 'Textile Technology',
    'TT': 'Textile Technology',
  };

  void _seedFallbackOptions() {
    _courseOptions = List<String>.from(_fallbackCourses);
    _courseDisplayToQuery = {
      for (final course in _fallbackCourses) course: course,
    };
    _districtOptions = List<String>.from(_fallbackDistricts);
  }

  String _toFullCourseName(String rawCourse) {
    final trimmed = rawCourse.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final key = trimmed.toUpperCase();
    final mapped = _courseCodeToFullName[key];
    if (mapped != null) {
      return mapped;
    }

    if (trimmed.length <= 3 && !trimmed.contains(' ')) {
      return 'Specialization ($trimmed)';
    }

    return trimmed;
  }

  @override
  void initState() {
    super.initState();
    _seedFallbackOptions();
    _physicsController.addListener(_calculateCutoff);
    _chemistryController.addListener(_calculateCutoff);
    _mathsController.addListener(_calculateCutoff);
    _loadCourses();
    _loadDistricts();
    _loadPreferredCollegeOptions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _mobileController.dispose();
    _physicsController.dispose();
    _chemistryController.dispose();
    _mathsController.dispose();
    _nameFocusNode.dispose();
    _ageFocusNode.dispose();
    _mobileFocusNode.dispose();
    _physicsFocusNode.dispose();
    _chemistryFocusNode.dispose();
    _mathsFocusNode.dispose();
    super.dispose();
  }

  void _validateMarksInRealTime() {
    // Real-time validation for marks (0-100)
    double? physics = double.tryParse(_physicsController.text.trim());
    double? chemistry = double.tryParse(_chemistryController.text.trim());
    double? maths = double.tryParse(_mathsController.text.trim());

    setState(() {
      _step2FieldErrors['physics'] =
          _physicsController.text.trim().isNotEmpty &&
              (physics == null || physics < 0 || physics > 100);
      _step2FieldErrors['chemistry'] =
          _chemistryController.text.trim().isNotEmpty &&
              (chemistry == null || chemistry < 0 || chemistry > 100);
      _step2FieldErrors['maths'] = _mathsController.text.trim().isNotEmpty &&
          (maths == null || maths < 0 || maths > 100);
    });

    // Calculate cutoff if inputs are valid
    if ((_physicsController.text.trim().isNotEmpty &&
            !(_step2FieldErrors['physics'] ?? false)) &&
        (_chemistryController.text.trim().isNotEmpty &&
            !(_step2FieldErrors['chemistry'] ?? false)) &&
        (_mathsController.text.trim().isNotEmpty &&
            !(_step2FieldErrors['maths'] ?? false))) {
      _calculateCutoff();
    }
  }

  // Clear individual field errors as user starts typing (1/3 page)
  void _clearNameError() {
    setState(() {
      _fieldErrors['name'] = false;
    });
  }

  void _clearAgeError() {
    setState(() {
      _fieldErrors['age'] = false;
    });
  }

  void _clearMobileError() {
    setState(() {
      _fieldErrors['mobile'] = false;
    });
  }

  // Clear individual field errors as user starts typing (2/3 page)
  void _clearPhysicsError() {
    setState(() {
      _step2FieldErrors['physics'] = false;
    });
    _validateMarksInRealTime();
  }

  void _clearChemistryError() {
    setState(() {
      _step2FieldErrors['chemistry'] = false;
    });
    _validateMarksInRealTime();
  }

  void _clearMathsError() {
    setState(() {
      _step2FieldErrors['maths'] = false;
    });
    _validateMarksInRealTime();
  }

  void _calculateCutoff() {
    final p = double.tryParse(_physicsController.text) ?? 0.0;
    final c = double.tryParse(_chemistryController.text) ?? 0.0;
    final m = double.tryParse(_mathsController.text) ?? 0.0;
    setState(() {
      _cutoff = (p / 2) + (c / 2) + m;
    });
  }

  Future<void> _loadCourses() async {
    setState(() {
      _coursesLoading = true;
    });

    final courses = await _apiService.getCourses();
    if (!mounted) return;

    final resolved = courses.isEmpty ? _fallbackCourses : courses;
    final displayToQuery = <String, String>{};

    for (final rawCourse in resolved) {
      final display = _toFullCourseName(rawCourse);
      if (display.isEmpty) {
        continue;
      }
      displayToQuery.putIfAbsent(display, () => rawCourse.trim());
    }

    if (displayToQuery.isEmpty) {
      for (final fallback in _fallbackCourses) {
        displayToQuery[fallback] = fallback;
      }
    }

    final displayOptions = displayToQuery.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    setState(() {
      _courseDisplayToQuery = displayToQuery;
      _courseOptions = displayOptions;
      _coursesLoading = false;
      if (!_courseOptions.contains(_selectedInterest) &&
          _courseOptions.isNotEmpty) {
        _selectedInterest = _courseOptions.first;
      }
    });

    _loadPreferredCollegeOptions();
  }

  Future<void> _loadAvailableCoursesForCurrentInputs() async {
    if (_selectedCategory.isEmpty || _cutoff <= 0) {
      return;
    }

    if (_coursesLoading) {
      return;
    }

    setState(() {
      _coursesLoading = true;
    });

    final available = await _apiService.getAvailableCourses(
      category: _selectedCategory,
      cutoff: _cutoff,
    );
    if (!mounted) return;

    if (available.isEmpty) {
      setState(() {
        _coursesLoading = false;
      });
      return;
    }

    final displayToQuery = <String, String>{};
    for (final value in available) {
      final raw = value.trim();
      if (raw.isEmpty) {
        continue;
      }

      final display = _toFullCourseName(raw);
      if (display.isEmpty) {
        continue;
      }

      displayToQuery.putIfAbsent(display, () => raw);
    }

    if (displayToQuery.isEmpty) {
      setState(() {
        _coursesLoading = false;
      });
      return;
    }

    final displayOptions = displayToQuery.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    setState(() {
      _courseDisplayToQuery = displayToQuery;
      _courseOptions = displayOptions;
      _coursesLoading = false;
      if (!_courseOptions.contains(_selectedInterest) &&
          _courseOptions.isNotEmpty) {
        _selectedInterest = _courseOptions.first;
      }
    });

    _loadPreferredCollegeOptions();
  }

  Future<void> _loadDistricts() async {
    final districts = await _apiService.getDistricts();
    if (!mounted) return;

    final normalized = districts
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final resolved =
        normalized.isEmpty ? _fallbackDistricts : ['Any', ...normalized];

    setState(() {
      _districtOptions = resolved;
      if (!_districtOptions.contains(_selectedDistrict)) {
        _selectedDistrict = _districtOptions.first;
      }
    });

    _loadPreferredCollegeOptions();
  }

  List<String> get _selectedPreferredCollegeIds {
    return _selectedPreferredColleges
        .map((item) => item.collegeId.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _loadPreferredCollegeOptions() async {
    final selectedCourse = _selectedInterest.trim();
    if (selectedCourse.isEmpty) {
      return;
    }

    setState(() {
      _collegeOptionsLoading = true;
    });

    final queryCourse = _courseDisplayToQuery[selectedCourse] ?? selectedCourse;
    final options = await _apiService.getCollegeOptions(
      preferredCourse: queryCourse,
      district: null,
      category: _selectedCategory,
      cutoff: _cutoff,
    );

    if (!mounted) {
      return;
    }

    final selectedById = {
      for (final option in _selectedPreferredColleges) option.collegeId: option,
    };

    final nextSelected = options
        .where((option) => selectedById.containsKey(option.collegeId))
        .toList();

    setState(() {
      _selectedPreferredColleges = nextSelected;
      _collegeOptionsLoading = false;
    });
  }

  Future<void> _openPreferredCollegePicker() async {
    final selectedIds = _selectedPreferredCollegeIds.toSet();

    // Load all colleges using category and cutoff from earlier pages
    setState(() => _collegeOptionsLoading = true);

    List<CollegeOption> allColleges = [];

    // Try to fetch colleges for multiple courses using the category and cutoff
    final commonCourses = [
      'Computer Science Engineering',
      'Information Technology',
      'Mechanical Engineering',
      'Civil Engineering',
      'Electrical and Electronics Engineering',
      'Electronics and Communication Engineering',
      'Electronics and Instrumentation Engineering',
      'Biomedical Engineering',
      'Biotechnology',
      'Chemical Engineering',
      'Artificial Intelligence and Data Science',
      'Automobile Engineering',
      'Aeronautical Engineering',
      'Production Engineering',
      'Mining Engineering',
      'Petrochemical Engineering',
    ];

    final collegesMap = <String, CollegeOption>{};

    for (final course in commonCourses) {
      try {
        final options = await _apiService.getCollegeOptions(
          preferredCourse: course,
          district: null,
          category: _selectedCategory.isNotEmpty ? _selectedCategory : null,
          cutoff: _cutoff > 0 ? _cutoff : null,
        );

        for (final option in options) {
          collegesMap[option.collegeId] = option;
        }
      } catch (e) {
        debugPrint('Error fetching colleges for $course: $e');
      }
    }

    allColleges = collegesMap.values.toList();
    allColleges.sort((a, b) => a.collegeName.compareTo(b.collegeName));

    setState(() => _collegeOptionsLoading = false);

    if (!mounted) return;

    if (allColleges.isEmpty) {
      _showSnackBar('No colleges available. Please try again.');
      return;
    }

    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final searchController = TextEditingController();
        String query = '';

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = allColleges.where((option) {
              if (query.trim().isEmpty) {
                return true;
              }

              // Case-insensitive search
              final normalizedQuery = query.toLowerCase();
              return option.collegeName.toLowerCase().contains(normalizedQuery);
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.78,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose Colleges (1-426)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose up to $_maxPreferredColleges colleges (Total: ${allColleges.length})',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search college by name (case-insensitive)',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) {
                          setSheetState(() {
                            query = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Results: ${filtered.length} colleges',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No colleges found matching "$query"',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final option = filtered[index];
                                  final isSelected =
                                      selectedIds.contains(option.collegeId);

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFEFF6FF)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF1D4ED8)
                                            : const Color(0xFFBFDBFE),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      title: Text(
                                        _stripSpecializationCode(
                                            option.collegeName),
                                        style: const TextStyle(
                                          color: Color(0xFF1F2937),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'ID: ${option.collegeId}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                      onTap: () {
                                        setSheetState(() {
                                          if (isSelected) {
                                            selectedIds
                                                .remove(option.collegeId);
                                            return;
                                          }

                                          if (selectedIds.length >=
                                              _maxPreferredColleges) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'You can select only $_maxPreferredColleges colleges.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          selectedIds.add(option.collegeId);
                                        });
                                      },
                                      trailing: CircleAvatar(
                                        radius: 14,
                                        backgroundColor: isSelected
                                            ? const Color(0xFF2563EB)
                                            : Colors.white,
                                        child: Icon(
                                          isSelected
                                              ? Icons.check_rounded
                                              : Icons.add_rounded,
                                          size: 16,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF1D4ED8),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () =>
                              Navigator.of(context).pop(selectedIds),
                          child: const Text('Apply Selection'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    final selectedOptions = allColleges
        .where((option) => selected.contains(option.collegeId))
        .toList();

    setState(() {
      _selectedPreferredColleges = selectedOptions;
    });
  }

  bool _validateStep1() {
    // Validate Step 1 (1/3): Name, Age, Mobile
    // Reset all error states
    final newErrors = {
      'name': _nameController.text.trim().isEmpty ||
          _nameController.text.trim().length < 2,
      'age': _ageController.text.trim().isEmpty ||
          (int.tryParse(_ageController.text.trim()) ?? 0) < 17 ||
          (int.tryParse(_ageController.text.trim()) ?? 0) > 100,
      'mobile': _mobileController.text.trim().isEmpty ||
          _mobileController.text.trim().length < 10,
    };

    setState(() {
      _fieldErrors.addAll(newErrors);
    });

    // Find first empty/invalid field and focus on it
    if (newErrors['name'] == true) {
      _nameFocusNode.requestFocus();
      _showSnackBar('Please enter a valid name (at least 2 characters)');
      return false;
    }
    if (newErrors['age'] == true) {
      _ageFocusNode.requestFocus();
      _showSnackBar('Please enter a valid age (17-100)');
      return false;
    }
    if (newErrors['mobile'] == true) {
      _mobileFocusNode.requestFocus();
      _showSnackBar('Please enter a valid mobile number (10 digits)');
      return false;
    }

    // Clear errors if all valid
    setState(() {
      _fieldErrors['name'] = false;
      _fieldErrors['age'] = false;
      _fieldErrors['mobile'] = false;
    });

    return true;
  }

  bool _validateStep2() {
    // Validate Step 2 (2/3): Physics, Chemistry, Math marks (0-100)
    double? physics = double.tryParse(_physicsController.text.trim());
    double? chemistry = double.tryParse(_chemistryController.text.trim());
    double? maths = double.tryParse(_mathsController.text.trim());

    // Reset all error states
    final newErrors = {
      'physics': _physicsController.text.trim().isEmpty ||
          physics == null ||
          physics < 0 ||
          physics > 100,
      'chemistry': _chemistryController.text.trim().isEmpty ||
          chemistry == null ||
          chemistry < 0 ||
          chemistry > 100,
      'maths': _mathsController.text.trim().isEmpty ||
          maths == null ||
          maths < 0 ||
          maths > 100,
    };

    setState(() {
      _step2FieldErrors.addAll(newErrors);
    });

    // Find first empty/invalid field and focus on it
    if (newErrors['physics'] == true) {
      _physicsFocusNode.requestFocus();
      if (_physicsController.text.trim().isEmpty) {
        _showSnackBar('Please enter physics marks (0-100)');
      } else {
        _showSnackBar('Physics marks must be between 0 and 100');
      }
      return false;
    }
    if (newErrors['chemistry'] == true) {
      _chemistryFocusNode.requestFocus();
      if (_chemistryController.text.trim().isEmpty) {
        _showSnackBar('Please enter chemistry marks (0-100)');
      } else {
        _showSnackBar('Chemistry marks must be between 0 and 100');
      }
      return false;
    }
    if (newErrors['maths'] == true) {
      _mathsFocusNode.requestFocus();
      if (_mathsController.text.trim().isEmpty) {
        _showSnackBar('Please enter mathematics marks (0-100)');
      } else {
        _showSnackBar('Mathematics marks must be between 0 and 100');
      }
      return false;
    }

    // Calculate cutoff and verify it's valid
    _calculateCutoff();
    if (_cutoff <= 0) {
      _showSnackBar('Invalid marks - please check your entries');
      return false;
    }

    // Clear errors if all valid
    setState(() {
      _step2FieldErrors['physics'] = false;
      _step2FieldErrors['chemistry'] = false;
      _step2FieldErrors['maths'] = false;
    });

    return true;
  }

  bool _validateStep3() {
    // Validate Step 3 (3/3): Interest area, district, category, and hostel preference
    if (_selectedInterest.isEmpty) {
      _showSnackBar('Please select an area of interest');
      return false;
    }
    if (_selectedDistrict.isEmpty || _selectedDistrict == 'Any') {
      _showSnackBar('Please select a location');
      return false;
    }
    if (_selectedCategory.isEmpty) {
      _showSnackBar('Please select a category');
      return false;
    }
    if (_hostelPreference.isEmpty) {
      _showSnackBar('Please select hostel preference (Yes/No)');
      return false;
    }
    return true;
  }

  void _nextPage() async {
    if (_currentStep < 2) {
      // Validate current step before proceeding
      if (_currentStep == 0) {
        if (!_validateStep1()) {
          return;
        }
      } else if (_currentStep == 1) {
        if (!_validateStep2()) {
          return;
        }
        _loadAvailableCoursesForCurrentInputs();
      }

      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
      });
      return;
    }

    // Final validation before submission (Step 3)
    if (!_validateStep3()) {
      return;
    }

    setState(() => _isLoading = true);

    if (!mounted) return;

    if (_selectedPreferredCollegeIds.length > _maxPreferredColleges) {
      _showSnackBar('You can select only $_maxPreferredColleges colleges.');
      setState(() => _isLoading = false);
      return;
    }

    // Use assigned departments as courses for API call
    final selectedCoursesForResults = _assignedDepartments.isNotEmpty
        ? List<String>.from(_assignedDepartments)
        : [_selectedInterest];

    // Get the first assigned department or interest as the query
    final interestQuery = _assignedDepartments.isNotEmpty
        ? _assignedDepartments.first
        : _selectedInterest;
    try {
      final String? effectiveDistrict =
          _selectedDistrict == 'Any' ? null : _selectedDistrict;
      RecommendationResult recommendationResult =
          await _apiService.getRecommendationResult(
        category: _selectedCategory,
        cutoff: _cutoff,
        preferredCourse: interestQuery,
        district: effectiveDistrict,
        preferredCollegeIds: _selectedPreferredCollegeIds,
        preferredCollegeNames: _selectedPreferredColleges
            .map((item) => _stripSpecializationCode(item.collegeName))
            .toList(),
      );

      if (!mounted) return;

      if (recommendationResult.isEmpty) {
        final districtLabel = effectiveDistrict ?? 'all districts';
        _showSnackBar(
          'No exact $_selectedInterest seats found for $districtLabel at cutoff ${_cutoff.toStringAsFixed(1)}. Try Software/IT or another category.',
        );
      }

      Navigator.pushNamed(context, AppRoutes.analysisResults, arguments: {
        'name': _nameController.text.trim().isEmpty
            ? 'Student'
            : _nameController.text.trim(),
        'category': _selectedCategory,
        'cutoff': _cutoff,
        'selectedCourses': selectedCoursesForResults,
        'interest': interestQuery,
        'district': effectiveDistrict,
        'preferredCollegeIds': _selectedPreferredCollegeIds,
        'preferredColleges': _selectedPreferredColleges
            .map((item) => _stripSpecializationCode(item.collegeName))
            .toList(),
        'prefetchedResult': recommendationResult,
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch recommendations')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _previousPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
      });
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.userCategory);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _previousPage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20, color: Color(0xFF1F2937)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / 3,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                  minHeight: 8,
                ),
              ),
            ),
          ),
          Text(
            "${_currentStep + 1}/3",
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4F46E5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Student Analysis Setup",
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 8),
          const Text(
            "Enter your basic information",
            style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 32),
          _buildTextField("Name", "Enter your full name", _nameController,
              isName: true,
              focusNode: _nameFocusNode,
              hasError: _fieldErrors['name'] ?? false,
              onChanged: _clearNameError),
          const SizedBox(height: 20),
          _buildTextField("Age", "e.g. 18", _ageController,
              isAge: true,
              focusNode: _ageFocusNode,
              hasError: _fieldErrors['age'] ?? false,
              onChanged: _clearAgeError),
          const SizedBox(height: 20),
          _buildTextField(
              "Mobile Number", "Enter mobile number", _mobileController,
              isPhone: true,
              focusNode: _mobileFocusNode,
              hasError: _fieldErrors['mobile'] ?? false,
              onChanged: _clearMobileError),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Academic Details",
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 8),
          const Text(
            "Enter your marks to calculate cutoff",
            style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 32),
          _buildTextField("Physics Marks", "Out of 100", _physicsController,
              isNumber: true,
              focusNode: _physicsFocusNode,
              hasError: _step2FieldErrors['physics'] ?? false,
              onChanged: _clearPhysicsError),
          const SizedBox(height: 20),
          _buildTextField("Chemistry Marks", "Out of 100", _chemistryController,
              isNumber: true,
              focusNode: _chemistryFocusNode,
              hasError: _step2FieldErrors['chemistry'] ?? false,
              onChanged: _clearChemistryError),
          const SizedBox(height: 20),
          _buildTextField("Mathematics Marks", "Out of 100", _mathsController,
              isNumber: true,
              focusNode: _mathsFocusNode,
              hasError: _step2FieldErrors['maths'] ?? false,
              onChanged: _clearMathsError),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  "Your Cutoff",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4F46E5)),
                ),
                const SizedBox(height: 8),
                Text(
                  _cutoff.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Your Preferences",
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 32),
          // 1. Cutoff Display
          const Text(
            "Your Cutoff Score",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${_cutoff.toStringAsFixed(1)} / 200",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(height: 32),
          // 2. Location Preference
          const Text(
            "Location Preference",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                hint: const Text("Select Location"),
                value: _selectedDistrict == 'Any' ? null : _selectedDistrict,
                isExpanded: true,
                items: _districtOptions
                    .where((e) => e != 'Any')
                    .toList()
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedDistrict = val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 32),
          // 3. Area of Interest
          const Text(
            "Area of Interest",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _interestAreaOptions.map((interest) {
              final isSelected = _selectedInterest == interest;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedInterest = interest;
                    _assignedDepartments =
                        _interestAreaToDepartments[interest] ?? [];
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF4F46E5)
                          : Colors.grey.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    interest,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected ? Colors.white : const Color(0xFF374151),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          // 4. Category Selection
          const Text(
            "Select Category",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFE5E7EB),
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: const Color(0xFF4F46E5)
                                    .withValues(alpha: 0.1),
                                blurRadius: 8)
                          ]
                        : [],
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF4B5563),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          // 5. Hostel Facility
          const Text(
            "Hostel Facility Required",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            spacing: 12,
            children: ['Yes', 'No'].map((option) {
              final isSelected = _hostelPreference == option;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _hostelPreference = option),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? const Color(0xFF4F46E5) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF4F46E5)
                            : Colors.grey.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      option,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? Colors.white : const Color(0xFF374151),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          // 6. College Preference
          const Text(
            "College Preference",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose Colleges',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Select up to 5 colleges',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFBFDBFE), width: 1),
                      ),
                      child: Text(
                        '${_selectedPreferredColleges.length}/$_maxPreferredColleges',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_collegeOptionsLoading)
                  const LinearProgressIndicator(minHeight: 3),
                if (!_collegeOptionsLoading)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openPreferredCollegePicker,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Colleges'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_selectedPreferredColleges.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedPreferredColleges.map((option) {
                return Chip(
                  backgroundColor: const Color(0xFFEFF6FF),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  deleteIconColor: const Color(0xFF1D4ED8),
                  label: Text(
                    _stripSpecializationCode(option.collegeName),
                    style: const TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onDeleted: () {
                    setState(() {
                      _selectedPreferredColleges = _selectedPreferredColleges
                          .where((item) => item.collegeId != option.collegeId)
                          .toList();
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField(
      String label, String hint, TextEditingController controller,
      {bool isNumber = false,
      bool isPhone = false,
      bool isName = false,
      bool isAge = false,
      FocusNode? focusNode,
      bool hasError = false,
      VoidCallback? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color:
                  hasError ? const Color(0xFFDC2626) : const Color(0xFF374151)),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: (value) {
              if (onChanged != null) {
                onChanged();
              }
            },
            keyboardType: isNumber || isPhone || isAge
                ? TextInputType.number
                : TextInputType.text,
            maxLength: isName ? 50 : (isAge ? 3 : (isNumber ? 3 : null)),
            inputFormatters: [
              if (isName) LengthLimitingTextInputFormatter(50),
              if (isAge) FilteringTextInputFormatter.digitsOnly,
              if (isAge) LengthLimitingTextInputFormatter(3),
              if (isNumber && !isPhone) FilteringTextInputFormatter.digitsOnly,
              if (isNumber && !isPhone) LengthLimitingTextInputFormatter(3),
              if (isPhone) FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              counterText: isName ? null : '',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: hasError
                      ? const Color(0xFFDC2626)
                      : Colors.grey.withValues(alpha: 0.1),
                  width: hasError ? 2 : 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: hasError
                      ? const Color(0xFFDC2626)
                      : Colors.grey.withValues(alpha: 0.1),
                  width: hasError ? 2 : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: hasError
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF4F46E5),
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFFDC2626), width: 2),
              ),
            ),
          ),
        ),
        if (hasError)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'This field is required',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomButton() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(
                    _currentStep < 2 ? "Next →" : "Search Colleges",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }

  String _stripSpecializationCode(String collegeName) {
    // Remove specialization codes like specialization(AL), specialization(XC), etc.
    return collegeName
        .replaceAll(RegExp(r'\s*specialization\([A-Z]{2}\)\s*'), '')
        .trim();
  }
}
