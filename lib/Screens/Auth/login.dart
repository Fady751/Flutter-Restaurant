import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

final String APP_URL = dotenv.env['APP_URL']!;
final String APIKEY = dotenv.env['APIKEY']!;

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> signIn(BuildContext context) async {
    final url = Uri.parse("${APP_URL}:signInWithPassword?key=${APIKEY}");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": emailController.text.trim(),
        "password": passwordController.text.trim(),
        "returnSecureToken": true,
      }),
    );

    // print("STATUS CODE: ${response.statusCode}");

    if (response.statusCode != 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      String errorMessage = data['error']['message'];

      if(errorMessage == "INVALID_LOGIN_CREDENTIALS"){
        errorMessage = "Invalid email or password. Please try again or sign up.";
      }

      else if(errorMessage == "EMAIL_NOT_FOUND"){
        errorMessage = "Email not found. Please check your email or sign up.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$errorMessage")),
      );      return;
    }
    // print("BODY: ${response.body}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 80),
            const Text(
              "Welcome Back!",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 50),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                print("Login button pressed");
                signIn(context);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text("Login"),
            ),
             const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                print("signup button pressed");
                // signUp();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text("SignUp"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
