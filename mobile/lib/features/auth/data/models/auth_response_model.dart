class AuthResponseModel {
  const AuthResponseModel({
    required this.accessToken,
    required this.tokenType,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
    );
  }

  final String accessToken;
  final String tokenType;
}
