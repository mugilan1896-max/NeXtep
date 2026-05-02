import 'package:flutter/material.dart';
import 'package:guidex/models/recommendation.dart';

class FinalReportPage extends StatefulWidget {
  final String studentName;
  final String category;
  final double studentCutoff;
  final String preferredCourse;
  final String? district;
  final bool hostelRequired;
  final List<String> preferredCollegeIds;
  final List<String> preferredCollegeNames;
  final List<Recommendation>? allRecommendations;
  final List<Recommendation>? safeColleges;

  const FinalReportPage({
    super.key,
    required this.studentName,
    required this.category,
    required this.studentCutoff,
    required this.preferredCourse,
    this.district,
    required this.hostelRequired,
    required this.preferredCollegeIds,
    required this.preferredCollegeNames,
    this.allRecommendations,
    this.safeColleges,
  });

  @override
  State<FinalReportPage> createState() => _FinalReportPageState();
}

class _FinalReportPageState extends State<FinalReportPage> {


  late List<Recommendation> _filteredSafeColleges;

  @override
  void initState() {
    super.initState();
    _filteredSafeColleges = _generateSafeColleges();
  }

  List<Recommendation> _generateSafeColleges() {
    final safe = widget.safeColleges ?? widget.allRecommendations ?? [];

    // We no longer filter by safe margin, we show exact probability for preferred colleges
    final filtered = safe.toList();

    // Sort by probability (highest first)
    filtered.sort((a, b) => b.probability.compareTo(a.probability));

    // Return top 5
    return filtered.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Final Report'),
        elevation: 0,
        backgroundColor: const Color(0xFF4F46E5),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Student Profile Header
              _buildStudentHeader(),
              const SizedBox(height: 24),

              // Safe Colleges Section
              _buildSafeCollegesSection(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Student Profile',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.studentName,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildProfileInfo(
                  icon: Icons.trending_up,
                  label: 'Cutoff',
                  value: widget.studentCutoff.toStringAsFixed(2),
                ),
              ),
              Expanded(
                child: _buildProfileInfo(
                  icon: Icons.school,
                  label: 'Category',
                  value: widget.category.toUpperCase(),
                ),
              ),
              Expanded(
                child: _buildProfileInfo(
                  icon: Icons.code,
                  label: 'Course',
                  value: _getShortCourseName(widget.preferredCourse),
                ),
              ),
            ],
          ),
          if (widget.district != null && widget.district!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'District: ${widget.district}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.white.withValues(alpha: 0.8),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSafeCollegesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.green.shade500,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preferred Colleges',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  'Top ${_filteredSafeColleges.length} preferred colleges based on your chances',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_filteredSafeColleges.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Text(
                'No preferred colleges found for this cutoff.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          Column(
            children: _filteredSafeColleges.asMap().entries.map((entry) {
              final index = entry.key;
              final college = entry.value;
              return _buildCollegeCard(college, index + 1);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildCollegeCard(Recommendation college, int rank) {
    String chanceText = '';
    if (college.probability >= 90) {
      chanceText = 'Excellent';
    } else if (college.probability >= 75) {
      chanceText = 'Strong';
    } else if (college.probability >= 60) {
      chanceText = 'Moderate';
    } else if (college.probability >= 40) {
      chanceText = 'Low';
    } else {
      chanceText = 'Very Low';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // College Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  college.collegeName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  college.courseName,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '🎯 Chance: ${college.probability}% ($chanceText)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: college.probability >= 75 ? Colors.green.shade700 : (college.probability >= 60 ? Colors.orange.shade700 : Colors.red.shade700),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text(
                      '📊 Your cutoff: ${widget.studentCutoff.toStringAsFixed(1)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    Text(
                      '📉 College cutoff: ${college.cutoff.toStringAsFixed(1)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getShortCourseName(String course) {
    const courseMap = {
      'Computer Science Engineering': 'CSE',
      'Information Technology': 'IT',
      'Electronics and Communication Engineering': 'ECE',
      'Electrical and Electronics Engineering': 'EEE',
      'Mechanical Engineering': 'ME',
      'Civil Engineering': 'CE',
      'Artificial Intelligence and Data Science': 'AI&DS',
      'Biomedical Engineering': 'BME',
      'Chemical Engineering': 'ChE',
      'Biotechnology': 'BT',
    };
    return courseMap[course] ?? course.substring(0, 3).toUpperCase();
  }
}
