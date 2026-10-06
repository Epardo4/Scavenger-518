import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthPage extends StatefulWidget{
    const AuthPage({super.key});

    @override
    State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>{
    bool isLogin = true;
    bool obscurePassword = true;
    bool obscureConfirmPassword = true;
    bool isLoading = false;

    //user input
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    Future<void> resetPassword() async{
      final email = emailController.text.trim();

      if(email.isEmpty){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your email address.')
          )
        );
        return;
      }

      try{
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: email
        );

        if(!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent. Check your inbox.')
          )
        );
      }on FirebaseAuthException catch(e){
        if(!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text(e.message ?? 'Unable to send password reset to your email.')
          )
        );
      }

    }

    //handles login/sign up
    Future<void> submit() async {
      if (isLoading) return;

      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      final confirmPassword = confirmPasswordController.text.trim();

      if (email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your email address.')),
        );
        return;
      }

      if (password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your password.')),
        );
        return;
      }

      if (!isLogin) {
        if (password.length < 6) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password must be at least 6 characters.')),
          );
          return; // Fix: Only return if password is less than 6 chars
        }

        if (password != confirmPassword) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Passwords do not match.')),
          );
          return; // Fix: Only return if passwords don't match
        }
      }

      try {
        setState(() { isLoading = true; });

        if (isLogin) {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } else {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isLogin ? 'Successfully logged in!' : 'Account Created Successfully',
            ),
          ),
        );
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? e.code)),
        );
      } finally {
        if (mounted) {
          setState(() { isLoading = false; });
        }
      }
    }

    @override
    void dispose(){
      emailController.dispose();
      passwordController.dispose();
      confirmPasswordController.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context){
      return Scaffold(
        appBar: AppBar(
          title: Text(isLogin ? 'Log In' : 'Sign Up')
        ),
        body: Center(
          child: SizedBox(
            width: 400,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLogin ? 'Welcome Back!' : 'Create an Account',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold
                    )
                  ),

                  const SizedBox(height: 30),

                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder()
                    )
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility : Icons.visibility_off
                        ),
                        onPressed: () {
                          setState(() {obscurePassword = !obscurePassword;});
                        }
                      )
                    )
                  ),

                  if(isLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: resetPassword,
                        child: const Text('Forgot Password?')
                      )
                    ),

                  if(!isLogin)...[
                    const SizedBox(height: 16),

                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        border: OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirmPassword ? Icons.visibility : Icons.visibility_off
                          ),
                          onPressed: () {
                            setState(() {obscureConfirmPassword = !obscureConfirmPassword;});
                          }
                        )
                      )
                    )
                  ],

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : submit,
                      child: isLoading ? 
                      const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      :  Text(isLogin ? 'Login' : 'Sign Up')
                    )
                  ),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () {
                      setState(() {isLogin = !isLogin;});
                    },
                    child: Text(
                      isLogin ? 'Need an account? Sign Up' : 'Already have an account? Log In'
                    )
                  )
                ]
              )
            )
          )
        )
      );
    }
}
