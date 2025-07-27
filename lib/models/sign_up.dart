class Sign_Up {
  final int status, id;
  final String username;
  final String email;
  final String password;
  final String first_name;
  final String last_name;
  final String gender;
  final String dob;
  final String created_at;

  Sign_Up({
    required this.id,
    required this.status,
    required this.username,
    required this.email,
    required this.password,
    required this.first_name,
    required this.last_name,
    required this.gender,
    required this.dob,
    required this.created_at,
  });
}