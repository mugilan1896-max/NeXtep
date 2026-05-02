package com.pathwise.backend.controller;

import com.pathwise.backend.dto.CollegeOptionResponse;
import com.pathwise.backend.dto.FinalReportResponse;
import com.pathwise.backend.dto.RecommendationResponse;
import com.pathwise.backend.service.CollegeScoringService;
import com.pathwise.backend.service.RecommendationService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class RecommendationController {

    private final RecommendationService recommendationService;
    private final CollegeScoringService collegeScoringService;

    public RecommendationController(
            RecommendationService recommendationService,
            CollegeScoringService collegeScoringService) {
        this.recommendationService = recommendationService;
        this.collegeScoringService = collegeScoringService;
    }

    @GetMapping("/districts")
    public ResponseEntity<List<String>> getDistricts() {
        return ResponseEntity.ok(recommendationService.getAllDistricts());
    }

    @GetMapping("/courses")
    public ResponseEntity<List<String>> getCourses() {
        return ResponseEntity.ok(recommendationService.getAllCourses());
    }

    @GetMapping("/available-courses")
    public ResponseEntity<List<String>> getAvailableCourses(
            @RequestParam String category,
            @RequestParam Double cutoff) {
        return ResponseEntity.ok(recommendationService.getAvailableCourses(category, cutoff));
    }

    @GetMapping("/college-options")
    public ResponseEntity<List<CollegeOptionResponse>> getCollegeOptions(
            @RequestParam(name = "preferred_course", required = false) String preferredCourseSnake,
            @RequestParam(name = "preferredCourse", required = false) String preferredCourseCamel,
            @RequestParam(required = false) String district) {
        final String preferredCourse = preferredCourseSnake != null
                ? preferredCourseSnake
                : preferredCourseCamel;

        if (preferredCourse == null || preferredCourse.isBlank()) {
            return ResponseEntity.ok(List.of());
        }

        return ResponseEntity.ok(recommendationService.getCollegeOptions(preferredCourse, district));
    }

    @PostMapping("/recommend")
    public ResponseEntity<Map<String, List<RecommendationResponse>>> recommend(
            @RequestBody Map<String, Object> requestBody) {

        String category = readString(requestBody, "category");
        Double studentCutoff = readDouble(requestBody, "student_cutoff");
        String preferredCourse = readString(requestBody, "preferred_course");
        String district = readString(requestBody, "district");
        List<String> preferredColleges = readStringList(requestBody, "preferred_colleges");

        if (category == null || studentCutoff == null || preferredCourse == null) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of(
                    "preferred_colleges", List.of(),
                    "safe_colleges", List.of()
            ));
        }

        Map<String, List<RecommendationResponse>> response =
                recommendationService.getPreferenceDrivenRecommendations(
                        category,
                        studentCutoff,
                        preferredCourse,
                        district,
                        preferredColleges
                );

        return ResponseEntity.ok(response);
    }

    @PostMapping("/final-report")
    public ResponseEntity<FinalReportResponse> generateFinalReport(
            @RequestBody Map<String, Object> requestBody) {

        String studentName = readString(requestBody, "student_name");
        String category = readString(requestBody, "category");
        Double studentCutoff = readDouble(requestBody, "student_cutoff");
        String preferredCourse = readString(requestBody, "preferred_course");
        String district = readString(requestBody, "district");
        Boolean hostelRequired = readBoolean(requestBody, "hostel_required");
        List<String> preferredCollegeIds = readStringList(requestBody, "preferred_college_ids");
        List<String> preferredCollegeNames = readStringList(requestBody, "preferred_college_names");

        if (category == null || studentCutoff == null || preferredCourse == null) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(
                    FinalReportResponse.builder()
                            .studentName(studentName)
                            .studentCutoff(studentCutoff)
                            .safeColleges(List.of())
                            .targetColleges(List.of())
                            .build()
            );
        }

        FinalReportResponse report = collegeScoringService.generateFinalReport(
                studentName,
                category,
                studentCutoff,
                preferredCourse,
                district,
                hostelRequired,
                preferredCollegeIds,
                preferredCollegeNames
        );

        return ResponseEntity.ok(report);
    }

    private Boolean readBoolean(Map<String, Object> body, String snakeCaseKey) {
        Object value = body.get(snakeCaseKey);
        if (value == null) {
            value = body.get(toCamelCase(snakeCaseKey));
        }

        if (value instanceof Boolean) {
            return (Boolean) value;
        }

        if (value instanceof String) {
            String str = ((String) value).trim().toLowerCase();
            return "true".equals(str) || "yes".equals(str) || "1".equals(str);
        }

        return false;
    }

    private String readString(Map<String, Object> body, String snakeCaseKey) {
        Object value = body.get(snakeCaseKey);
        if (value == null) {
            value = body.get(toCamelCase(snakeCaseKey));
        }
        if (value == null) {
            return null;
        }

        String text = value.toString().trim();
        return text.isEmpty() ? null : text;
    }

    private Double readDouble(Map<String, Object> body, String snakeCaseKey) {
        Object value = body.get(snakeCaseKey);
        if (value == null) {
            value = body.get(toCamelCase(snakeCaseKey));
        }

        if (value instanceof Number) {
            return ((Number) value).doubleValue();
        }

        if (value instanceof String) {
            try {
                return Double.parseDouble(((String) value).trim());
            } catch (NumberFormatException ignored) {
                return null;
            }
        }

        return null;
    }

    private List<String> readStringList(Map<String, Object> body, String snakeCaseKey) {
        Object value = body.get(snakeCaseKey);
        if (value == null) {
            value = body.get(toCamelCase(snakeCaseKey));
        }

        if (!(value instanceof List<?>)) {
            return List.of();
        }

        List<String> items = new ArrayList<>();
        for (Object entry : (List<?>) value) {
            if (entry == null) {
                continue;
            }
            String text = entry.toString().trim();
            if (!text.isEmpty()) {
                items.add(text);
            }
        }
        return items;
    }

    private String toCamelCase(String snakeCase) {
        StringBuilder builder = new StringBuilder();
        boolean upperNext = false;
        for (char ch : snakeCase.toCharArray()) {
            if (ch == '_') {
                upperNext = true;
                continue;
            }
            builder.append(upperNext ? Character.toUpperCase(ch) : ch);
            upperNext = false;
        }
        return builder.toString();
    }
}
