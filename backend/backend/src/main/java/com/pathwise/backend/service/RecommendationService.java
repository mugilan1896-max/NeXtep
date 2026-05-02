package com.pathwise.backend.service;

import com.pathwise.backend.dto.CollegeOptionResponse;
import com.pathwise.backend.dto.RecommendationResponse;
import com.pathwise.backend.model.College;
import com.pathwise.backend.model.CutoffHistory;
import com.pathwise.backend.repository.CollegeRepository;
import com.pathwise.backend.repository.CutoffHistoryRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

@Service
public class RecommendationService {

    private final CutoffHistoryRepository cutoffHistoryRepository;
    private final CollegeRepository collegeRepository;

    private static final Pattern NON_ALNUM_PATTERN = Pattern.compile("[^a-z0-9]+");
    private static final Pattern SPACE_PATTERN = Pattern.compile("\\s+");

    private static final String PREFERRED = "preferred";
    private static final String SAFE = "safe";

    private static final int SAFE_RESULT_LIMIT = 15;

    public RecommendationService(
            CutoffHistoryRepository cutoffHistoryRepository,
            CollegeRepository collegeRepository
    ) {
        this.cutoffHistoryRepository = cutoffHistoryRepository;
        this.collegeRepository = collegeRepository;
    }

    @Transactional(readOnly = true)
    public List<String> getAllDistricts() {
        return collegeRepository.findDistinctDistricts();
    }

    @Transactional(readOnly = true)
    public List<String> getAllCourses() {
        return cutoffHistoryRepository.findDistinctBranchesFromCutoffHistory();
    }

    @Transactional(readOnly = true)
    public List<String> getAvailableCourses(String category, Double cutoff) {
        String normalizedCategory = normalizeCategory(category);
        if (normalizedCategory == null || cutoff == null) {
            return Collections.emptyList();
        }

        return cutoffHistoryRepository
                .findAvailableBranchesByCategoryAndCutoff(normalizedCategory, cutoff)
                .stream()
                .filter(Objects::nonNull)
                .map(String::trim)
                .filter(value -> !value.isEmpty())
                .map(value -> value.toUpperCase(Locale.ROOT))
                .distinct()
                .sorted(String::compareToIgnoreCase)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<CollegeOptionResponse> getCollegeOptions(String courseName, String district) {
        String exactBranchCode = resolveExactBranchCode(courseName);
        if (exactBranchCode == null || exactBranchCode.isBlank()) {
            return Collections.emptyList();
        }

        final String requestedDistrict = normalizeText(district);
        final Map<String, College> collegeByName = buildCollegeLookup();
        final Map<String, CollegeOptionResponse> unique = new LinkedHashMap<>();

        List<Object[]> rows = cutoffHistoryRepository.findCollegeOptionsByCourse(exactBranchCode);
        for (Object[] row : rows) {
            if (row == null || row.length < 2) {
                continue;
            }

            String collegeCode = safeTrim(row[0] == null ? null : row[0].toString());
            String collegeName = safeTrim(row[1] == null ? null : row[1].toString());
            if (collegeCode.isEmpty() || collegeName.isEmpty()) {
                continue;
            }

            College college = findCollegeDetails(collegeName, collegeByName);
            String collegeDistrict = college == null ? null : safeTrim(college.getDistrict());

            if (!districtMatches(requestedDistrict, collegeDistrict, collegeName)) {
                continue;
            }

            unique.putIfAbsent(
                    normalizeText(collegeCode),
                    CollegeOptionResponse.builder()
                            .collegeId(collegeCode)
                            .collegeName(collegeName)
                            .district(collegeDistrict)
                            .build()
            );
        }

        return unique.values().stream()
                .sorted(Comparator.comparing(item -> safeTrim(item.getCollegeName()).toLowerCase(Locale.ROOT)))
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public Map<String, List<RecommendationResponse>> getPreferenceDrivenRecommendations(
            String category,
            Double studentCutoff,
            String preferredCourse,
            String district,
            List<String> preferredCollegeIds
    ) {
        final Map<String, List<RecommendationResponse>> result = emptyPreferenceResult();

        String normalizedCategory = normalizeCategory(category);
        if (normalizedCategory == null || studentCutoff == null || studentCutoff <= 0.0) {
            return result;
        }

        String exactBranchCode = resolveExactBranchCode(preferredCourse);
        if (exactBranchCode == null || exactBranchCode.isBlank()) {
            return result;
        }

        List<CutoffHistory> rows = cutoffHistoryRepository
                .findByCategoryAndExactBranchWithCommunityRange(normalizedCategory, exactBranchCode);

        if (rows.isEmpty()) {
            return result;
        }

        final Map<String, College> collegeByName = buildCollegeLookup();
        final String requestedDistrict = normalizeText(district);

        List<RecommendationResponse> preferredResults = new ArrayList<>();
        List<RecommendationResponse> safeResults = new ArrayList<>();

        for (CutoffHistory row : rows) {
            if (row == null || row.getCollegeCode() == null) {
                continue;
            }

            if (!normalizeText(row.getBranch()).equals(normalizeText(exactBranchCode))) {
                continue;
            }

            double communityMin = getCutoffByCategory(row, normalizedCategory);
            double communityMax = getMaxCutoffByCategory(row, normalizedCategory);

            if (Double.isNaN(communityMax) || communityMax <= 0.0
                    || Double.isNaN(communityMin) || communityMin <= 0.0) {
                continue;
            }

            int probability = calculateProbability(studentCutoff, communityMin);
            if (probability < 10) {
                continue;
            }

            College college = findCollegeDetails(row.getCollegeName(), collegeByName);
            String collegeDistrict = college == null ? null : safeTrim(college.getDistrict());
            String collegeType = college == null ? null : safeTrim(college.getCollegeType());

            if (!districtMatches(requestedDistrict, collegeDistrict, row.getCollegeName())) {
                continue;
            }

            String bucket = probability >= 70 ? PREFERRED : SAFE;
            RecommendationResponse dto = toRecommendation(
                    row,
                    communityMin,
                    communityMax,
                    probability,
                    bucket,
                    collegeDistrict,
                    collegeType
            );

            if (PREFERRED.equals(bucket)) {
                preferredResults.add(dto);
            } else {
                safeResults.add(dto);
            }
        }

        Comparator<RecommendationResponse> probabilityDesc = Comparator
                .comparing(RecommendationResponse::getProbability, Comparator.nullsLast(Comparator.reverseOrder()))
                .thenComparing(RecommendationResponse::getCutoff, Comparator.nullsLast(Comparator.reverseOrder()))
                .thenComparing(item -> safeTrim(item.getCollegeName()).toLowerCase(Locale.ROOT));

        preferredResults = preferredResults.stream()
                .sorted(probabilityDesc)
                .collect(Collectors.toList());

        safeResults = safeResults.stream()
                .filter(item -> item.getProbability() != null && item.getProbability() >= 30 && item.getProbability() <= 69)
                .sorted(probabilityDesc)
                .limit(SAFE_RESULT_LIMIT)
                .collect(Collectors.toList());

        result.put("preferred_colleges", preferredResults);
        result.put("safe_colleges", safeResults);

        return result;
    }

    private Map<String, List<RecommendationResponse>> emptyPreferenceResult() {
        Map<String, List<RecommendationResponse>> result = new LinkedHashMap<>();
        result.put("preferred_colleges", new ArrayList<>());
        result.put("safe_colleges", new ArrayList<>());
        return result;
    }

    private RecommendationResponse toRecommendation(
            CutoffHistory row,
            double closingCutoff,
            double openingCutoff,
            int probability,
            String category,
            String collegeDistrict,
            String collegeType
    ) {
        return RecommendationResponse.builder()
                .collegeName(row.getCollegeName())
                .courseName(mapToFullName(row.getBranch()))
                .district(collegeDistrict)
                .collegeType(collegeType)
                .cutoff(closingCutoff)
                .maxCutoff(openingCutoff)
                .probability(probability)
                .category(category)
                .score((double) probability)
                .recommendationType(category)
                .build();
    }

    private int calculateProbability(double studentCutoff, double collegeCutoff) {
        if (Double.isNaN(studentCutoff) || Double.isNaN(collegeCutoff) || collegeCutoff <= 0.0) {
            return -1;
        }

        double ratio = studentCutoff / collegeCutoff;

        if (ratio >= 1.0) {
            return 95; // 90-95%
        } else if (ratio >= 0.9) {
            return 82; // 75-90%
        } else if (ratio >= 0.8) {
            return 68; // 60-75%
        } else if (ratio >= 0.7) {
            return 50; // 40-60%
        } else {
            return 25; // 10-40%
        }
    }

    private Map<String, College> buildCollegeLookup() {
        return collegeRepository.findAll().stream()
                .filter(Objects::nonNull)
                .filter(college -> college.getCollegeName() != null && !college.getCollegeName().isBlank())
                .collect(Collectors.toMap(
                        college -> normalizeText(college.getCollegeName()),
                        college -> college,
                        (left, right) -> left,
                        LinkedHashMap::new
                ));
    }

    private College findCollegeDetails(String rawCollegeName, Map<String, College> collegeByName) {
        if (rawCollegeName == null || rawCollegeName.isBlank() || collegeByName.isEmpty()) {
            return null;
        }

        String normalizedRaw = normalizeText(rawCollegeName);
        College exact = collegeByName.get(normalizedRaw);
        if (exact != null) {
            return exact;
        }

        String primaryName = normalizeText(extractPrimaryCollegeName(rawCollegeName));
        College primaryExact = collegeByName.get(primaryName);
        if (primaryExact != null) {
            return primaryExact;
        }

        return collegeByName.entrySet().stream()
                .filter(entry -> normalizedRaw.contains(entry.getKey())
                        || (!primaryName.isBlank() && entry.getKey().contains(primaryName)))
                .max(Comparator.comparingInt(entry -> entry.getKey().length()))
                .map(Map.Entry::getValue)
                .orElse(null);
    }

    private boolean districtMatches(String requestedDistrict, String collegeDistrict, String rawCollegeName) {
        if (requestedDistrict == null || requestedDistrict.isBlank()) {
            return true;
        }

        if (collegeDistrict != null && !collegeDistrict.isBlank()) {
            return normalizeText(collegeDistrict).equals(requestedDistrict);
        }

        String normalizedCollegeName = normalizeText(rawCollegeName);
        return normalizedCollegeName.contains(requestedDistrict);
    }

    private String extractPrimaryCollegeName(String collegeName) {
        String firstLine = safeTrim(collegeName).split("\\n")[0];
        return firstLine.split(",")[0].trim();
    }

    private String safeTrim(String value) {
        return value == null ? "" : value.trim();
    }

    private String normalizeText(String value) {
        if (value == null || value.isBlank()) {
            return "";
        }
        String lower = value.toLowerCase(Locale.ROOT);
        String alnum = NON_ALNUM_PATTERN.matcher(lower).replaceAll(" ");
        return SPACE_PATTERN.matcher(alnum).replaceAll(" ").trim();
    }

    public double getCutoffByCategory(CutoffHistory ch, String category) {
        if (ch == null || category == null) {
            return Double.NaN;
        }

        switch (category.toUpperCase(Locale.ROOT)) {
            case "OC":
                return ch.getOcMin() == null ? Double.NaN : ch.getOcMin();
            case "BC":
                return ch.getBcMin() == null ? Double.NaN : ch.getBcMin();
            case "BCM":
                return ch.getBcmMin() == null ? Double.NaN : ch.getBcmMin();
            case "MBC":
                return ch.getMbcMin() == null ? Double.NaN : ch.getMbcMin();
            case "SC":
                return ch.getScMin() == null ? Double.NaN : ch.getScMin();
            case "SCA":
                return ch.getScaMin() == null ? Double.NaN : ch.getScaMin();
            case "ST":
                return ch.getStMin() == null ? Double.NaN : ch.getStMin();
            default:
                return Double.NaN;
        }
    }

    private double getMaxCutoffByCategory(CutoffHistory ch, String category) {
        if (ch == null || category == null) {
            return Double.NaN;
        }

        switch (category.toUpperCase(Locale.ROOT)) {
            case "OC":
                return ch.getOcMax() == null ? Double.NaN : ch.getOcMax();
            case "BC":
                return ch.getBcMax() == null ? Double.NaN : ch.getBcMax();
            case "BCM":
                return ch.getBcmMax() == null ? Double.NaN : ch.getBcmMax();
            case "MBC":
                return ch.getMbcMax() == null ? Double.NaN : ch.getMbcMax();
            case "SC":
                return ch.getScMax() == null ? Double.NaN : ch.getScMax();
            case "SCA":
                return ch.getScaMax() == null ? Double.NaN : ch.getScaMax();
            case "ST":
                return ch.getStMax() == null ? Double.NaN : ch.getStMax();
            default:
                return Double.NaN;
        }
    }

    private String normalizeCategory(String category) {
        if (category == null || category.isBlank()) {
            return null;
        }
        String normalized = category.trim().toUpperCase(Locale.ROOT);
        switch (normalized) {
            case "OC":
            case "BC":
            case "BCM":
            case "MBC":
            case "SC":
            case "SCA":
            case "ST":
                return normalized;
            default:
                return null;
        }
    }

    private String resolveExactBranchCode(String courseInput) {
        if (courseInput == null || courseInput.isBlank()) {
            return null;
        }

        String cleaned = courseInput.trim();
        String upper = cleaned.toUpperCase(Locale.ROOT);
        if (!upper.contains(" ")) {
            return upper;
        }

        String normalized = normalizeText(cleaned);
        switch (normalized) {
            case "computer science":
            case "computer science engineering":
            case "computer science and engineering":
                return "CS";
            case "artificial intelligence and data science":
            case "ai and data science":
            case "ai ds":
            case "ai&ds":
                return "AD";
            case "artificial intelligence and machine learning":
            case "ai and machine learning":
            case "ai ml":
                return "AM";
            case "electronics and communication engineering":
                return "EC";
            case "electrical and electronics engineering":
                return "EE";
            case "electronics and instrumentation engineering":
                return "EI";
            case "information technology":
                return "IT";
            case "civil engineering":
                return "CE";
            case "mechanical engineering":
                return "ME";
            case "biomedical engineering":
                return "BME";
            default:
                return upper;
        }
    }

    private String mapToFullName(String rawName) {
        if (rawName == null) {
            return "Unknown Course";
        }

        String trimmed = rawName.trim();
        String lower = trimmed.toLowerCase(Locale.ROOT);
        switch (lower) {
            case "cs":
            case "cse":
            case "computer science engineering":
            case "computer science and engineering":
                return "Computer Science Engineering";
            case "ad":
            case "ai&ds":
            case "ai ds":
            case "artificial intelligence and data science":
                return "Artificial Intelligence and Data Science";
            case "am":
            case "ai ml":
            case "artificial intelligence and machine learning":
                return "Artificial Intelligence and Machine Learning";
            case "it":
            case "information technology":
                return "Information Technology";
            case "ec":
            case "ece":
            case "electronics and communication engineering":
                return "Electronics and Communication Engineering";
            case "ee":
            case "eee":
            case "electrical and electronics engineering":
                return "Electrical and Electronics Engineering";
            case "ei":
            case "eie":
                return "Electronics and Instrumentation Engineering";
            case "ce":
            case "ci":
            case "cl":
            case "civil":
                return "Civil Engineering";
            case "me":
            case "mechanical engineering":
                return "Mechanical Engineering";
            case "bm":
            case "bme":
            case "biomedical engineering":
                return "Biomedical Engineering";
            default:
                if (trimmed.length() <= 3 && !trimmed.contains(" ")) {
                    return "Specialization (" + trimmed.toUpperCase(Locale.ROOT) + ")";
                }
                return trimmed;
        }
    }
}
