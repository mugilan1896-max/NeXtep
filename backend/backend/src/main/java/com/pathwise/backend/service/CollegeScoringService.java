package com.pathwise.backend.service;

import com.pathwise.backend.dto.FinalReportResponse;
import com.pathwise.backend.model.College;
import com.pathwise.backend.model.CutoffHistory;
import com.pathwise.backend.repository.CollegeRepository;
import com.pathwise.backend.repository.CutoffHistoryRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

@Service
public class CollegeScoringService {

    private final CutoffHistoryRepository cutoffHistoryRepository;
    private final CollegeRepository collegeRepository;
    private final RecommendationService recommendationService;

    private static final Pattern NON_ALNUM_PATTERN = Pattern.compile("[^a-z0-9]+");
    private static final Pattern SPACE_PATTERN = Pattern.compile("\\s+");
    private static final double SAFE_MARGIN = 5.0;  // Cutoff margin for safe colleges
    
    // Interest to Department mapping
    private static final Map<String, List<String>> INTEREST_MAPPING = Map.ofEntries(
        Map.entry("app", List.of("CSE", "IT", "CS", "CST")),
        Map.entry("web", List.of("CSE", "IT", "CS", "CST")),
        Map.entry("ai", List.of("AIML", "CSE", "AD", "AI&DS", "CG")),
        Map.entry("ml", List.of("AIML", "CSE", "AD", "AI&DS", "CG")),
        Map.entry("embedded", List.of("ECE", "EIE", "ETE", "MCT")),
        Map.entry("bio", List.of("BME", "BT", "IBT")),
        Map.entry("mechanical", List.of("ME", "MAE")),
        Map.entry("civil", List.of("CE", "CI", "CL", "CIVIL")),
        Map.entry("electrical", List.of("EEE", "EE")),
        Map.entry("electronics", List.of("ECE", "EIE", "ETE"))
    );
    
    // Weight distribution
    private static final double WEIGHT_CUTOFF = 0.40;
    private static final double WEIGHT_LOCATION = 0.20;
    private static final double WEIGHT_INTEREST = 0.15;
    private static final double WEIGHT_HOSTEL = 0.10;
    private static final double WEIGHT_CATEGORY = 0.10;
    private static final double WEIGHT_PREFERENCE = 0.05;

    public CollegeScoringService(
            CutoffHistoryRepository cutoffHistoryRepository,
            CollegeRepository collegeRepository,
            RecommendationService recommendationService
    ) {
        this.cutoffHistoryRepository = cutoffHistoryRepository;
        this.collegeRepository = collegeRepository;
        this.recommendationService = recommendationService;
    }

    @Transactional(readOnly = true)
    public FinalReportResponse generateFinalReport(
            String studentName,
            String category,
            Double studentCutoff,
            String preferredCourse,
            String district,
            Boolean hostelRequired,
            List<String> preferredCollegeIds,
            List<String> preferredCollegeNames
    ) {
        
        FinalReportResponse report = FinalReportResponse.builder()
                .studentName(sanitize(studentName))
                .studentCutoff(studentCutoff)
                .studentCategory(category)
                .preferredCourse(preferredCourse)
                .preferredLocation(district)
                .hostelRequired(hostelRequired != null && hostelRequired)
                .preferredCollegeIds(preferredCollegeIds != null ? preferredCollegeIds : new ArrayList<>())
                .build();

        if (studentCutoff == null || studentCutoff <= 0 || preferredCourse == null) {
            report.setSafeColleges(new ArrayList<>());
            report.setTargetColleges(new ArrayList<>());
            return report;
        }

        // Get all colleges for this course
        List<CutoffHistory> allColleges = cutoffHistoryRepository
                .findByCategoryAndExactBranchWithCommunityRange(
                    normalizeCategory(category),
                    resolveExactBranchCode(preferredCourse)
                );

        Map<String, College> collegeDetailsMap = buildCollegeLookup();

        // Calculate Safe Colleges (10)
        List<FinalReportResponse.SafeCollegeResponse> safeColleges = calculateSafeColleges(
                allColleges, studentCutoff, category, collegeDetailsMap, preferredCourse
        );
        report.setSafeColleges(safeColleges);

        // Calculate Target Colleges (10) with weighted scoring
        List<FinalReportResponse.TargetCollegeResponse> targetColleges = calculateTargetColleges(
                allColleges, studentName, studentCutoff, category, preferredCourse, 
                district, hostelRequired, preferredCollegeIds, collegeDetailsMap
        );
        report.setTargetColleges(targetColleges);

        return report;
    }

    private List<FinalReportResponse.SafeCollegeResponse> calculateSafeColleges(
            List<CutoffHistory> colleges,
            Double studentCutoff,
            String category,
            Map<String, College> collegeDetailsMap,
            String preferredCourse
    ) {
        String normalizedCategory = normalizeCategory(category);
        
        return colleges.stream()
                .map(college -> {
                    double collegeCutoff = getCutoffByCategory(college, normalizedCategory);
                    if (Double.isNaN(collegeCutoff) || collegeCutoff <= 0) {
                        return null;
                    }
                    
                    // Safe if student cutoff >= college cutoff - margin
                    if (studentCutoff < collegeCutoff - SAFE_MARGIN) {
                        return null;
                    }
                    
                    double probability = calculateProbability(studentCutoff, collegeCutoff);
                    
                    College collegeDetail = collegeDetailsMap.get(sanitizeCollegeName(college.getCollegeName()));
                    String district = collegeDetail != null ? collegeDetail.getDistrict() : null;
                    
                    return FinalReportResponse.SafeCollegeResponse.builder()
                            .collegeName(college.getCollegeName())
                            .course(mapToFullCourseName(college.getBranch()))
                            .collegeCutoff(collegeCutoff)
                            .district(district)
                            .probability(probability)
                            .chanceLabel(formatChanceLabel(probability))
                            .build();
                })
                .filter(Objects::nonNull)
                .sorted(Comparator.comparing(FinalReportResponse.SafeCollegeResponse::getProbability).reversed())
                .limit(10)
                .collect(Collectors.toList());
    }

    private List<FinalReportResponse.TargetCollegeResponse> calculateTargetColleges(
            List<CutoffHistory> colleges,
            String studentName,
            Double studentCutoff,
            String category,
            String preferredCourse,
            String district,
            Boolean hostelRequired,
            List<String> preferredCollegeIds,
            Map<String, College> collegeDetailsMap
    ) {
        String normalizedCategory = normalizeCategory(category);
        String normalizedDistrict = normalizeText(district);
        Set<String> preferredSet = new HashSet<>(
            preferredCollegeIds != null ? preferredCollegeIds : new ArrayList<>()
        );

        return colleges.stream()
                .map(college -> {
                    double collegeCutoff = getCutoffByCategory(college, normalizedCategory);
                    if (Double.isNaN(collegeCutoff) || collegeCutoff <= 0) {
                        return null;
                    }
                    
                    College collegeDetail = collegeDetailsMap.get(sanitizeCollegeName(college.getCollegeName()));
                    String collegeDistrict = collegeDetail != null ? collegeDetail.getDistrict() : null;

                    // Calculate individual scores
                    double cutoffScore = calculateCutoffScore(studentCutoff, collegeCutoff);
                    double locationScore = calculateLocationScore(normalizedDistrict, collegeDistrict);
                    double interestScore = calculateInterestScore(preferredCourse, college.getBranch());
                    double hostelScore = calculateHostelScore(hostelRequired, collegeDetail);
                    double categoryScore = calculateCategoryScore(studentCutoff, collegeCutoff);
                    double preferenceBonus = preferredSet.contains(college.getCollegeCode()) ? 0.2 : 0.0;

                    // Calculate weighted final score
                    double finalScore = (WEIGHT_CUTOFF * cutoffScore) +
                                      (WEIGHT_LOCATION * locationScore) +
                                      (WEIGHT_INTEREST * interestScore) +
                                      (WEIGHT_HOSTEL * hostelScore) +
                                      (WEIGHT_CATEGORY * categoryScore) +
                                      (WEIGHT_PREFERENCE * preferenceBonus);

                    // Convert to percentage (0-100)
                    double scorePercentage = finalScore * 100;
                    
                    return FinalReportResponse.TargetCollegeResponse.builder()
                            .collegeName(college.getCollegeName())
                            .course(mapToFullCourseName(college.getBranch()))
                            .scorePercentage(Math.min(scorePercentage, 100.0))
                            .district(collegeDistrict)
                            .chanceLabel(getChanceLabel(scorePercentage))
                            .cutoffScore(cutoffScore)
                            .locationScore(locationScore)
                            .interestScore(interestScore)
                            .hostelScore(hostelScore)
                            .categoryScore(categoryScore)
                            .preferenceBonus(preferenceBonus)
                            .build();
                })
                .filter(Objects::nonNull)
                .sorted(Comparator.comparing(FinalReportResponse.TargetCollegeResponse::getScorePercentage).reversed())
                .limit(10)
                .collect(Collectors.toList());
    }

    // SCORING FORMULAS

    private double calculateCutoffScore(double studentCutoff, double collegeCutoff) {
        double score = studentCutoff / collegeCutoff;
        return Math.min(score, 1.2);  // Cap at 1.2
    }

    private double calculateLocationScore(String preferredDistrict, String collegeDistrict) {
        if (preferredDistrict == null || preferredDistrict.isEmpty() || "any".equalsIgnoreCase(preferredDistrict)) {
            return 0.5;  // Neutral if not specified
        }
        if (collegeDistrict == null) {
            return 0.3;  // Different if unknown
        }
        
        String pref = normalizeText(preferredDistrict);
        String coll = normalizeText(collegeDistrict);
        
        if (pref.equals(coll)) {
            return 1.0;  // Exact match
        } else if (isNearby(pref, coll)) {
            return 0.7;  // Nearby
        } else {
            return 0.3;  // Different
        }
    }

    private double calculateInterestScore(String studentInterest, String courseBranch) {
        if (studentInterest == null || courseBranch == null) {
            return 0.5;
        }
        
        String interest = normalizeText(studentInterest).toLowerCase();
        String branch = normalizeText(courseBranch).toUpperCase();
        
        for (Map.Entry<String, List<String>> entry : INTEREST_MAPPING.entrySet()) {
            if (interest.contains(entry.getKey())) {
                if (entry.getValue().stream().anyMatch(b -> branch.contains(b))) {
                    return 1.0;  // Match
                } else {
                    // Check for related courses
                    if (branch.contains("CS") || branch.contains("IT") || branch.contains("ECE")) {
                        return 0.7;  // Related
                    }
                }
            }
        }
        
        return 0.2;  // Mismatch
    }

    private double calculateHostelScore(Boolean hostelRequired, College collegeDetail) {
        if (hostelRequired == null || !hostelRequired) {
            return 0.5;  // Ignore if not required
        }
        
        if (collegeDetail == null) {
            return 0.5;  // Unknown
        }
        
        boolean hasHostel = collegeDetail.getHostelAvailable() != null && collegeDetail.getHostelAvailable();
        return hasHostel ? 1.0 : 0.0;
    }

    private double calculateCategoryScore(double studentCutoff, double collegeCutoff) {
        // If student's cutoff is significantly higher than college's requirement
        if (studentCutoff >= collegeCutoff + 5) {
            return 1.0;  // Category advantage exists
        }
        return 0.5;  // Standard category score
    }

    private double calculateProbability(double studentCutoff, double collegeCutoff) {
        double ratio = studentCutoff / collegeCutoff;
        if (ratio >= 1.2) return 95.0;
        if (ratio >= 1.1) return 85.0;
        if (ratio >= 1.0) return 75.0;
        if (ratio >= 0.95) return 60.0;
        if (ratio >= 0.9) return 40.0;
        return 20.0;
    }

    private String getChanceLabel(double scorePercentage) {
        if (scorePercentage >= 70) {
            return "Strong Chance (" + (int)scorePercentage + "%)";
        } else if (scorePercentage >= 50) {
            return "Moderate (" + (int)scorePercentage + "%)";
        } else {
            return "Dream (" + (int)scorePercentage + "%)";
        }
    }

    private String formatChanceLabel(double probability) {
        if (probability >= 80) return "High (80-95%)";
        if (probability >= 60) return "Moderate (60-79%)";
        return "Low (<60%)";
    }

    private boolean isNearby(String district1, String district2) {
        // Define nearby districts (Tamil Nadu geography)
        Map<String, List<String>> nearbyMap = Map.ofEntries(
            Map.entry("CHENNAI", List.of("CHENGALPATTU", "KANCHEEPURAM", "TIRUVALLUR")),
            Map.entry("COIMBATORE", List.of("TIRUPPUR", "NILGIRIS")),
            Map.entry("SALEM", List.of("KRISHNAGIRI", "DHARMAPURI")),
            Map.entry("MADURAI", List.of("THENI", "DINDIGUL")),
            Map.entry("TIRUCHIRAPPALLI", List.of("PERAMBALUR", "KARUR")),
            Map.entry("VELLORE", List.of("KRISHNAGIRI", "TIRUPPATTUR"))
        );
        
        List<String> nearby = nearbyMap.getOrDefault(district1, new ArrayList<>());
        return nearby.contains(district2);
    }

    // UTILITY METHODS (from RecommendationService)

    private String normalizeCategory(String category) {
        if (category == null) return null;
        String normalized = NON_ALNUM_PATTERN.matcher(category.toLowerCase()).replaceAll("");
        return normalized.isEmpty() ? null : normalized;
    }

    private String resolveExactBranchCode(String courseName) {
        if (courseName == null || courseName.isBlank()) return null;
        String normalized = NON_ALNUM_PATTERN.matcher(courseName.toLowerCase()).replaceAll("");
        
        // This would need to match against actual database branch codes
        // For now, return the normalized version
        return normalized.isEmpty() ? null : normalized;
    }

    private double getCutoffByCategory(CutoffHistory row, String category) {
        if (row == null || category == null) return Double.NaN;
        
        switch (category) {
            case "oc": return row.getOcMin() != null ? row.getOcMin() : Double.NaN;
            case "bcm": return row.getBcmMin() != null ? row.getBcmMin() : Double.NaN;
            case "bc": return row.getBcMin() != null ? row.getBcMin() : Double.NaN;
            case "mbc": return row.getMbcMin() != null ? row.getMbcMin() : Double.NaN;
            case "sc": return row.getScMin() != null ? row.getScMin() : Double.NaN;
            case "sca": return row.getScaMin() != null ? row.getScaMin() : Double.NaN;
            default: return Double.NaN;
        }
    }

    private String mapToFullCourseName(String branch) {
        if (branch == null) return "Unknown";
        // Map common course codes to full names
        Map<String, String> courseMap = Map.ofEntries(
            Map.entry("CS", "Computer Science Engineering"),
            Map.entry("IT", "Information Technology"),
            Map.entry("ECE", "Electronics and Communication Engineering"),
            Map.entry("EEE", "Electrical and Electronics Engineering"),
            Map.entry("ME", "Mechanical Engineering"),
            Map.entry("CE", "Civil Engineering"),
            Map.entry("BME", "Biomedical Engineering"),
            Map.entry("BT", "Biotechnology"),
            Map.entry("CHE", "Chemical Engineering"),
            Map.entry("AIML", "Artificial Intelligence and Machine Learning"),
            Map.entry("AD", "Artificial Intelligence and Data Science")
        );
        return courseMap.getOrDefault(branch.toUpperCase(), branch);
    }

    private Map<String, College> buildCollegeLookup() {
        return collegeRepository.findAll().stream()
                .collect(Collectors.toMap(
                    c -> sanitizeCollegeName(c.getCollegeName()),
                    c -> c
                ));
    }

    private String sanitizeCollegeName(String name) {
        if (name == null) return "";
        return NON_ALNUM_PATTERN.matcher(name.toLowerCase()).replaceAll("");
    }

    private String normalizeText(String text) {
        if (text == null) return "";
        return NON_ALNUM_PATTERN.matcher(text.toLowerCase()).replaceAll("");
    }

    private String sanitize(String text) {
        return text != null ? text.trim() : "Student";
    }
}
