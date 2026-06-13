class ApiConstants {
  // Base URL - خلي الدومين بدل الـ IP والـ Port
static const String baseUrl = "https://cases.farahdent.com";


  // Auth endpoints
  static const String login = '/auth/login';
  static const String me = '/auth/me';

  // Patient endpoints
  static const String patients = '/patients';
  static String patientById(String id) => '/patients/$id';

  // Step endpoints
  static String uploadImages(String patientId, int stepNumber) =>
      '/patients/$patientId/steps/$stepNumber/upload';
  static String markStepDone(String patientId, int stepNumber) =>
      '/patients/$patientId/steps/$stepNumber/done';
  static String deleteImage(String patientId, int stepNumber, String imageId) =>
      '/patients/$patientId/steps/$stepNumber/images/$imageId';

  // Metrics
  static const String metrics = '/metrics';
}
