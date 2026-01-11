class RegistrationResponse {
  final String message;
  final String email;

  RegistrationResponse({
    required this.message,
    required this.email,
  });

  factory RegistrationResponse.fromJson(Map<String, dynamic> json) {
    return RegistrationResponse(
      message: json['message'] as String,
      email: json['email'] as String,
    );
  }
}
