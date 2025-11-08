//
//  SignUpView.swift
//  Nurtra V2
//
//  Created by Giang Michael Dao on 10/28/25.
//

import SwiftUI
import AuthenticationServices

struct SignUpView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var isLoading = false
    
    var isPasswordValid: Bool {
        password.count >= 6
    }
    
    var doPasswordsMatch: Bool {
        password == confirmPassword
    }
    
    var isFormValid: Bool {
        !name.isEmpty && !email.isEmpty && isPasswordValid && doPasswordsMatch
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    Text("Create Account")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Sign up to get started")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)
                .padding(.bottom, 20)
                
                // Social Sign-In Buttons
                VStack(spacing: 12) {
                    // Apple Sign In
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                            let nonce = authManager.startSignInWithApple()
                            request.nonce = nonce
                        },
                        onCompletion: { result in
                            Task {
                                isLoading = true
                                switch result {
                                case .success(let authorization):
                                    do {
                                        try await authManager.handleSignInWithApple(authorization)
                                        dismiss()
                                    } catch {
                                        print("Apple Sign-In error: \(error)")
                                    }
                                case .failure(let error):
                                    print("Apple Sign-In failed: \(error)")
                                }
                                isLoading = false
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    
                    // Google Sign In
                    Button(action: {
                        Task {
                            isLoading = true
                            do {
                                try await authManager.signInWithGoogle()
                                dismiss()
                            } catch {
                                print("Google Sign-In error: \(error)")
                            }
                            isLoading = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "globe")
                                .font(.title3)
                            Text("Continue with Google")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal)
                
                // Divider
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                    Text("or")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                }
                .padding(.horizontal)
                
                // Email/Password Form
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("Enter your name", text: $name)
                            .textFieldStyle(.plain)
                            .textContentType(.name)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("Enter your email", text: $email)
                            .textFieldStyle(.plain)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        SecureField("Create a password (min 6 characters)", text: $password)
                            .textFieldStyle(.plain)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        if !password.isEmpty && !isPasswordValid {
                            Text("Password must be at least 6 characters")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        SecureField("Confirm your password", text: $confirmPassword)
                            .textFieldStyle(.plain)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        if !confirmPassword.isEmpty && !doPasswordsMatch {
                            Text("Passwords do not match")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Error Message
                if let errorMessage = authManager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                // Sign Up Button
                Button(action: {
                    Task {
                        isLoading = true
                        do {
                            try await authManager.signUp(email: email, password: password, name: name)
                            dismiss()
                        } catch {
                            print("Sign up error: \(error)")
                        }
                        isLoading = false
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("Sign Up")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(!isFormValid || isLoading)
                .opacity((!isFormValid || isLoading) ? 0.6 : 1.0)
                .padding(.horizontal)
                
                // Terms and Privacy
                Text("By signing up, you agree to our Terms of Service and Privacy Policy")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.bottom, 40)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SignUpView()
            .environmentObject(AuthenticationManager())
    }
}


