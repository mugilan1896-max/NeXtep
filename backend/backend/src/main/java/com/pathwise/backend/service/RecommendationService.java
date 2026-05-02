package com.pathwise.backend.service;

import com.pathwise.backend.dto.CollegeOptionResponse;
import com.pathwise.backend.dto.RecommendationResponse;
import com.pathwise.backend.dto.TargetCollegeResponse;
import com.pathwise.backend.repository.CutoffHistoryRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
public class RecommendationService {

    private final CutoffHistoryRepository cutoffHistoryRepository;

    public RecommendationService(CutoffHistoryRepository cutoffHistoryRepository) {
        this.cutoffHistoryRepository = cutoffHistoryRepository;
    }

    // ========================================================================
    // MAIN ENDPOINT: Returns both Preferred Analysis + Target Colleges
    // ========================================================================
    @Transactional(readOnly = true)
    public TargetCollegeResponse getTargetColleges(
            Double studentCutoff,
            String community,
            String preferredCity,
            String preferredCourse,
            String hostelRequired,
            List<String> preferredColleges) {

        String comm = community.toLowerCase(Locale.ROOT);
        List<Object[]> rows = cutoffHistoryRepository.findTargetColleges(comm);

        // ⭐ SECTION 1: Preferred Colleges Analysis (probability formula)
        List<TargetCollegeResponse.PreferredCollegeAnalysis> preferredAnalysis = new ArrayList<>();

        // 🎯 SECTION 2: Target Colleges (weighted scoring)
        List<TargetCollegeResponse.TargetCollege> targetColleges = new ArrayList<>();

        for (Object[] row : rows) {
            String collegeName = String.valueOf(row[0]);
            String branchName = String.valueOf(row[1]);
            Double collegeCutoff = convertToDouble(row[2]);
            String city = String.valueOf(row[3]);
            String district = String.valueOf(row[4]);
            String branchCode = String.valueOf(row[5]);

            if (collegeCutoff == null || collegeCutoff <= 0) continue;

            // --- Check if this college is in the user's preferred list ---
            boolean isPreferred = false;
            if (preferredColleges != null) {
                for (String pref : preferredColleges) {
                    if (collegeName.toLowerCase().contains(pref.toLowerCase())
                            || pref.toLowerCase().contains(collegeName.toLowerCase())) {
                        isPreferred = true;
                        break;
                    }
                }
            }

            // ⭐ If preferred: calculate probability using ratio formula
            if (isPreferred) {
                double probability = calculateProbability(studentCutoff, collegeCutoff);
                String chanceLabel = getProbabilityLabel(probability);

                preferredAnalysis.add(TargetCollegeResponse.PreferredCollegeAnalysis.builder()
                        .college_name(collegeName)
                        .course(branchName)
                        .your_cutoff(studentCutoff)
                        .college_cutoff(collegeCutoff)
                        .probability(Math.round(probability * 100.0) / 100.0)
                        .chance_label(chanceLabel)
                        .build());
            }

            // 🎯 Calculate weighted score for ALL colleges (target section)
            double score = calculateWeightedScore(
                    studentCutoff, collegeCutoff,
                    preferredCity, city, district,
                    preferredCourse, branchCode, branchName,
                    hostelRequired,
                    collegeName, preferredColleges
            );

            targetColleges.add(TargetCollegeResponse.TargetCollege.builder()
                    .college_name(collegeName)
                    .course(branchName)
                    .score(Math.round(score * 100.0) / 100.0)
                    .chance_label(getWeightedChanceLabel(score))
                    .build());
        }

        // Sort preferred by probability DESC
        preferredAnalysis.sort(Comparator.comparing(
                TargetCollegeResponse.PreferredCollegeAnalysis::getProbability).reversed());

        // Sort target by score DESC and take top 10
        List<TargetCollegeResponse.TargetCollege> top10 = targetColleges.stream()
                .sorted(Comparator.comparing(TargetCollegeResponse.TargetCollege::getScore).reversed())
                .limit(10)
                .collect(Collectors.toList());

        return TargetCollegeResponse.builder()
                .preferred_colleges_analysis(preferredAnalysis)
                .target_colleges(top10)
                .build();
    }

    // ========================================================================
    // FINAL REPORT ENDPOINT: Generates top 5 Safe (Preferred) + 15 Target
    // ========================================================================
    @Transactional(readOnly = true)
    public com.pathwise.backend.dto.FinalReportResponse generateFinalReport(com.pathwise.backend.dto.FinalReportRequest request) {
        String comm = request.getCategory() != null ? request.getCategory().toLowerCase(Locale.ROOT) : "";
        List<Object[]> rows = cutoffHistoryRepository.findTargetColleges(comm);

        Double studentCutoff = request.getStudent_cutoff() != null ? request.getStudent_cutoff() : 0.0;
        String preferredCourse = request.getPreferred_course() != null ? request.getPreferred_course() : "";
        String preferredDistrict = request.getDistrict() != null ? request.getDistrict() : "";
        boolean hostelRequired = request.getHostel_required() != null ? request.getHostel_required() : false;
        List<String> preferredCollegeNames = request.getPreferred_college_names() != null ? request.getPreferred_college_names() : new ArrayList<>();

        List<com.pathwise.backend.dto.FinalReportResponse.SafeCollegeResponse> safeColleges = new ArrayList<>();
        List<com.pathwise.backend.dto.FinalReportResponse.TargetCollegeResponse> targetColleges = new ArrayList<>();

        for (Object[] row : rows) {
            String collegeName = String.valueOf(row[0]);
            String branchName = String.valueOf(row[1]);
            Double collegeCutoff = convertToDouble(row[2]);
            String city = String.valueOf(row[3]);
            String district = String.valueOf(row[4]);
            String branchCode = String.valueOf(row[5]);

            if (collegeCutoff == null || collegeCutoff <= 0) continue;

            // --- Check if preferred ---
            boolean isPreferred = false;
            if (preferredCollegeNames != null) {
                for (String pref : preferredCollegeNames) {
                    if (collegeName.toLowerCase().contains(pref.toLowerCase()) || pref.toLowerCase().contains(collegeName.toLowerCase())) {
                        isPreferred = true;
                        break;
                    }
                }
            }

            // ⭐ 1. SAFE COLLEGES (Top 5 based on User Preferences)
            if (isPreferred) {
                double probability = calculateProbability(studentCutoff, collegeCutoff);
                String chanceLabel = getProbabilityLabel(probability);

                safeColleges.add(com.pathwise.backend.dto.FinalReportResponse.SafeCollegeResponse.builder()
                        .collegeName(collegeName)
                        .course(branchName)
                        .collegeCutoff(collegeCutoff)
                        .chanceLabel(chanceLabel)
                        .probability(Math.round(probability * 100.0) / 100.0)
                        .district(district)
                        .build());
            }

            // 🎯 2. TARGET COLLEGES (15 with new specific algorithm)
            // 1. Cutoff Score
            double ratio = studentCutoff / collegeCutoff;
            double cutoffScore;
            if (ratio >= 1.0) cutoffScore = 1.0;
            else if (ratio >= 0.85) cutoffScore = ratio;
            else if (ratio >= 0.7) cutoffScore = ratio * 0.8;
            else cutoffScore = ratio * 0.5;

            // 2. Location Score
            double locationScore = 0.3;
            if (!preferredDistrict.isEmpty() && !preferredDistrict.equalsIgnoreCase("any")) {
                String prefDistLower = preferredDistrict.toLowerCase();
                String actDistLower = district != null ? district.toLowerCase() : "";
                String actCityLower = city != null ? city.toLowerCase() : "";

                if (actDistLower.equals(prefDistLower) || actCityLower.equals(prefDistLower)) {
                    locationScore = 1.0; // exactMatch
                } else if (actDistLower.contains(prefDistLower) || actCityLower.contains(prefDistLower)
                        || prefDistLower.contains(actDistLower) || prefDistLower.contains(actCityLower)) {
                    locationScore = 0.7; // nearby
                }
            } else {
                locationScore = 1.0; // No preference -> default to match
            }

            // 3. Interest Score
            double interestScore = 0.2;
            if (!preferredCourse.isEmpty()) {
                String prefCourseLower = preferredCourse.toLowerCase();
                String actBranchLower = branchName != null ? branchName.toLowerCase() : "";
                String actCodeLower = branchCode != null ? branchCode.toLowerCase() : "";

                if (actBranchLower.equals(prefCourseLower) || actCodeLower.equals(prefCourseLower)) {
                    interestScore = 1.0; // exactMatch
                } else if (matchesCourseAlias(prefCourseLower, actBranchLower) || actBranchLower.contains(prefCourseLower) || actCodeLower.contains(prefCourseLower)) {
                    interestScore = 0.7; // related
                }
            } else {
                interestScore = 1.0; // no preference
            }

            // 4. Hostel Score
            double hostelScore;
            if (hostelRequired) {
                hostelScore = 1.0; // Assuming available (as requested: hostelRequired && available)
            } else {
                hostelScore = 0.5;
            }

            // 5. Category Score
            // if (studentCategory == collegeCategory) categoryScore = 1; else categoryScore = 0.6;
            double categoryScore = 1.0; // In this system, we only fetch for the student's category

            // 6. Preference Boost
            double prefScore = isPreferred ? 1.0 : 0.0;

            // 🧮 FINAL SCORE FORMULA
            double finalScore = (0.4 * cutoffScore) +
                                (0.2 * locationScore) +
                                (0.15 * interestScore) +
                                (0.1 * hostelScore) +
                                (0.1 * categoryScore) +
                                (0.05 * prefScore);

            // 🎯 STEP 4: FILTER TARGET COLLEGES (0.55 to 0.85)
            if (finalScore >= 0.55 && finalScore <= 0.85) {
                double probability = finalScore * 100.0;
                
                String label;
                if (probability >= 80) label = "Strong";
                else if (probability >= 65) label = "Moderate";
                else label = "Dream";

                targetColleges.add(com.pathwise.backend.dto.FinalReportResponse.TargetCollegeResponse.builder()
                        .collegeName(collegeName)
                        .course(branchName)
                        .scorePercentage(Math.round(probability * 100.0) / 100.0)
                        .district(district)
                        .chanceLabel(label)
                        .cutoffScore(Math.round(cutoffScore * 100.0) / 100.0)
                        .locationScore(Math.round(locationScore * 100.0) / 100.0)
                        .interestScore(Math.round(interestScore * 100.0) / 100.0)
                        .hostelScore(Math.round(hostelScore * 100.0) / 100.0)
                        .categoryScore(Math.round(categoryScore * 100.0) / 100.0)
                        .preferenceBonus(Math.round(prefScore * 100.0) / 100.0)
                        .build());
            }
        }

        // Sort safeColleges by probability descending and limit to 5
        safeColleges.sort(Comparator.comparing(com.pathwise.backend.dto.FinalReportResponse.SafeCollegeResponse::getProbability).reversed());
        List<com.pathwise.backend.dto.FinalReportResponse.SafeCollegeResponse> finalSafeColleges = safeColleges.stream().limit(5).collect(Collectors.toList());

        // Sort targetColleges by finalScore descending and limit to 15
        targetColleges.sort(Comparator.comparing(com.pathwise.backend.dto.FinalReportResponse.TargetCollegeResponse::getScorePercentage).reversed());
        List<com.pathwise.backend.dto.FinalReportResponse.TargetCollegeResponse> finalTargetColleges = targetColleges.stream().limit(15).collect(Collectors.toList());

        return com.pathwise.backend.dto.FinalReportResponse.builder()
                .studentName(request.getStudent_name() != null ? request.getStudent_name() : "Student")
                .studentCutoff(studentCutoff)
                .studentCategory(request.getCategory() != null ? request.getCategory().toUpperCase() : "")
                .preferredCourse(preferredCourse)
                .preferredLocation(preferredDistrict)
                .hostelRequired(hostelRequired)
                .safeColleges(finalSafeColleges)
                .targetColleges(finalTargetColleges)
                .build();
    }

    // ========================================================================
    // ⭐ PREFERRED COLLEGES: Simple Probability Formula
    // probability = (student_cutoff / college_cutoff) × 100
    // Then tiered into realistic ranges
    // ========================================================================
    private double calculateProbability(Double studentCutoff, Double collegeCutoff) {
        double ratio = studentCutoff / collegeCutoff;

        if (ratio >= 1.0) {
            // Student cutoff >= college cutoff → 90-95%
            // The higher the ratio, the closer to 95%
            return Math.min(95.0, 90.0 + (ratio - 1.0) * 50.0);
        } else if (ratio >= 0.9) {
            // 0.9 to 1.0 → 75-90%
            double t = (ratio - 0.9) / 0.1; // 0 to 1 within range
            return 75.0 + t * 15.0;
        } else if (ratio >= 0.8) {
            // 0.8 to 0.9 → 60-75%
            double t = (ratio - 0.8) / 0.1;
            return 60.0 + t * 15.0;
        } else if (ratio >= 0.7) {
            // 0.7 to 0.8 → 40-60%
            double t = (ratio - 0.7) / 0.1;
            return 40.0 + t * 20.0;
        } else {
            // Below 0.7 → 10-40%
            double t = Math.max(0, ratio / 0.7);
            return 10.0 + t * 30.0;
        }
    }

    private String getProbabilityLabel(double probability) {
        if (probability >= 80) return "Strong";
        if (probability >= 60) return "Moderate";
        if (probability >= 40) return "Competitive";
        return "Dream";
    }

    // ========================================================================
    // 🎯 TARGET COLLEGES: Weighted Scoring Model
    // Score = 0.4×Cutoff + 0.2×Location + 0.15×Course + 0.1×Hostel
    //       + 0.1×Category + 0.05×Preference
    // ========================================================================
    private double calculateWeightedScore(
            Double studentCutoff, Double collegeCutoff,
            String preferredCity, String city, String district,
            String preferredCourse, String branchCode, String branchName,
            String hostelRequired,
            String collegeName, List<String> preferredColleges) {

        // 1. Cutoff Match Score (40%)
        double cutoffScore;
        double ratio = studentCutoff / collegeCutoff;
        if (ratio >= 1.0) {
            // Student meets or exceeds cutoff
            cutoffScore = Math.min(100, 80 + (ratio - 1.0) * 200);
        } else if (ratio >= 0.95) {
            cutoffScore = 70 + ((ratio - 0.95) / 0.05) * 10;
        } else if (ratio >= 0.9) {
            cutoffScore = 55 + ((ratio - 0.9) / 0.05) * 15;
        } else if (ratio >= 0.8) {
            cutoffScore = 30 + ((ratio - 0.8) / 0.1) * 25;
        } else {
            cutoffScore = Math.max(0, ratio * 37.5);
        }

        // 2. Location Match Score (20%)
        double locationScore = 30; // default: no match
        if (preferredCity != null && !preferredCity.isEmpty()) {
            String prefLower = preferredCity.toLowerCase();
            if (city != null && city.toLowerCase().contains(prefLower)) {
                locationScore = 100; // exact city match
            } else if (district != null && district.toLowerCase().contains(prefLower)) {
                locationScore = 70; // district match
            }
        } else {
            locationScore = 50; // no preference given
        }

        // 3. Course Interest Match (15%)
        double courseScore = 0;
        if (preferredCourse != null && !preferredCourse.isEmpty()) {
            String prefCourseLower = preferredCourse.toLowerCase();
            String branchLower = branchName != null ? branchName.toLowerCase() : "";
            String codeLower = branchCode != null ? branchCode.toLowerCase() : "";

            if (branchLower.contains(prefCourseLower) || codeLower.contains(prefCourseLower)
                    || prefCourseLower.contains(branchLower) || prefCourseLower.contains(codeLower)) {
                courseScore = 100; // course matches
            }
            // Partial match for common abbreviations
            else if (matchesCourseAlias(prefCourseLower, branchLower)) {
                courseScore = 80;
            }
        } else {
            courseScore = 50; // no preference
        }

        // 4. Hostel Facility Score (10%)
        double hostelScore = 50; // default neutral
        if ("yes".equalsIgnoreCase(hostelRequired)) {
            hostelScore = 70; // assume available unless we know otherwise
        }

        // 5. Category Advantage (10%)
        double categoryScore;
        if (ratio >= 1.0) {
            categoryScore = 100; // student cutoff exceeds college
        } else if (ratio >= 0.95) {
            categoryScore = 75;
        } else if (ratio >= 0.9) {
            categoryScore = 50;
        } else {
            categoryScore = 25;
        }

        // 6. Preference Boost (5%)
        double preferenceScore = 0;
        if (preferredColleges != null) {
            for (String pref : preferredColleges) {
                if (collegeName.toLowerCase().contains(pref.toLowerCase())
                        || pref.toLowerCase().contains(collegeName.toLowerCase())) {
                    preferenceScore = 100;
                    break;
                }
            }
        }

        return (0.40 * cutoffScore) +
               (0.20 * locationScore) +
               (0.15 * courseScore) +
               (0.10 * hostelScore) +
               (0.10 * categoryScore) +
               (0.05 * preferenceScore);
    }

    /**
     * Match common course abbreviations like CS → Computer Science
     */
    private boolean matchesCourseAlias(String preferred, String actual) {
        Map<String, List<String>> aliases = Map.of(
                "cs", List.of("computer science", "computer", "cse"),
                "cse", List.of("computer science", "computer", "cs"),
                "ece", List.of("electronics and communication", "electronics", "ec"),
                "eee", List.of("electrical and electronics", "electrical", "ee"),
                "mech", List.of("mechanical engineering", "mechanical"),
                "civil", List.of("civil engineering"),
                "it", List.of("information technology"),
                "ai", List.of("artificial intelligence", "ai and"),
                "aids", List.of("artificial intelligence and data science"),
                "bio", List.of("biotechnology", "biomedical", "bio technology")
        );

        List<String> expandedAliases = aliases.getOrDefault(preferred, List.of());
        for (String alias : expandedAliases) {
            if (actual.contains(alias)) return true;
        }
        // Also check reverse
        for (Map.Entry<String, List<String>> entry : aliases.entrySet()) {
            if (entry.getValue().stream().anyMatch(a -> a.contains(preferred))) {
                if (actual.contains(entry.getKey())) return true;
            }
        }
        return false;
    }

    private String getWeightedChanceLabel(double score) {
        if (score >= 70) return "Strong Chance";
        if (score >= 50) return "Moderate";
        return "Dream";
    }

    // ========================================================================
    // Legacy /api/recommend endpoint
    // ========================================================================
    @Transactional(readOnly = true)
    public Map<String, List<RecommendationResponse>> getRecommendations(Double userCutoff, String userCommunity) {
        String community = userCommunity.toLowerCase(Locale.ROOT);
        List<Object[]> rows = cutoffHistoryRepository.findTargetColleges(community);

        List<RecommendationResponse> safeColleges = new ArrayList<>();
        List<RecommendationResponse> preferredColleges = new ArrayList<>();

        for (Object[] row : rows) {
            String collegeName = String.valueOf(row[0]);
            String branchName = String.valueOf(row[1]);
            Double cutoff = convertToDouble(row[2]);

            if (cutoff == null) continue;

            RecommendationResponse response = RecommendationResponse.builder()
                    .collegeName(collegeName)
                    .courseName(branchName)
                    .cutoff(cutoff)
                    .category(community.toUpperCase(Locale.ROOT))
                    .build();

            if (cutoff <= userCutoff) {
                safeColleges.add(response);
            } else if (cutoff > userCutoff && cutoff <= userCutoff + 5) {
                preferredColleges.add(response);
            }
        }

        Map<String, List<RecommendationResponse>> result = new LinkedHashMap<>();
        result.put("safe_colleges", safeColleges);
        result.put("preferred_colleges", preferredColleges);

        return result;
    }

    @Transactional(readOnly = true)
    public List<String> getAllCourses() {
        return cutoffHistoryRepository.findDistinctBranches();
    }

    public long getCollegeCount() {
        return cutoffHistoryRepository.count();
    }

    @Transactional(readOnly = true)
    public List<CollegeOptionResponse> getCollegeOptions(String courseName) {
        List<CollegeOptionResponse> options = new ArrayList<>();

        if (courseName == null || courseName.trim().isEmpty()) {
            List<Object[]> allColleges = cutoffHistoryRepository.findAllColleges();
            for (Object[] row : allColleges) {
                Long collegeId = convertToLong(row[0]);
                String collegeName = String.valueOf(row[1]);
                String district = String.valueOf(row[2]);

                options.add(CollegeOptionResponse.builder()
                        .collegeId(collegeId != null ? collegeId.toString() : "")
                        .collegeName(collegeName)
                        .district(district != null ? district : "")
                        .build());
            }
        } else {
            List<Object[]> colleges = cutoffHistoryRepository.findCollegesByCourseName(courseName.trim());
            for (Object[] row : colleges) {
                Long collegeId = convertToLong(row[0]);
                String collegeName = String.valueOf(row[1]);
                String district = String.valueOf(row[2]);

                options.add(CollegeOptionResponse.builder()
                        .collegeId(collegeId != null ? collegeId.toString() : "")
                        .collegeName(collegeName)
                        .district(district != null ? district : "")
                        .build());
            }
        }

        return options;
    }

    private Long convertToLong(Object obj) {
        if (obj == null) return null;
        if (obj instanceof Number) return ((Number) obj).longValue();
        try {
            return Long.parseLong(obj.toString());
        } catch (Exception e) {
            return null;
        }
    }

    private Double convertToDouble(Object obj) {
        if (obj == null) return null;
        if (obj instanceof Number) return ((Number) obj).doubleValue();
        try {
            return Double.parseDouble(obj.toString());
        } catch (Exception e) {
            return null;
        }
    }
}
