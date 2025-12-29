//
//  SignInView.swift
//  Quarter
//
//  Created by Owen Wright on 12/19/25.
//

import SwiftUI
import Combine

struct SignInView: View {
    @State private var showPhoneEntry = false

    var body: some View {
        NavigationStack {
            WelcomeView(
                onContinue: { showPhoneEntry = true },
                onNoCookie: { showPhoneEntry = true }
            )
            .navigationDestination(isPresented: $showPhoneEntry) {
                SignInWithPhoneNumberView()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            AnalyticsManager.logScreen("SignInGate", className: "SignInView")
        }
    }
}

struct SignInWithPhoneNumberView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var phoneNumber: String = ""
    @State private var showVerification = false
    @State private var activeAlertMessage: String?

    private var isFormValid: Bool {
        phoneNumber.filter { $0.isNumber }.count == 10
    }

    private var formattedPhone: String {
        formatForDisplay(phoneNumber)
    }

    var body: some View {
        ZStack {
            Color("CookiesBackground")
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color("CookiesTextPrimary"))
                            .padding(12)
                            .background(Color("CookiesSurface"))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                VStack(spacing: 20) {
                    Spacer().frame(height: 20)

                    Text("Enter your phone number to sign in or get started")
                        .font(.system(size: 32, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color("CookiesTextPrimary"))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    TextField("Phone number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .padding()
                        .frame(height: 55)
                        .background(Color("CookiesSurface"))
                        .cornerRadius(12)
                        .font(.system(size: 18))
                        .foregroundColor(Color("CookiesTextPrimary"))
                        .onChange(of: phoneNumber) { _, newValue in
                            let digits = newValue.filter { $0.isNumber }
                            let trimmed = String(digits.prefix(10))
                            if trimmed != newValue {
                                phoneNumber = trimmed
                            }
                        }

                    Text("We'll send you a code to confirm it's you")
                        .font(.subheadline)
                        .foregroundColor(Color("CookiesTextSecondary"))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 15) {
                Button(action: {
                    authViewModel.sendVerificationCode(phoneNumber: phoneNumber)
                }) {
                    Text("Get verification code")
                        .font(.headline)
                        .foregroundColor(isFormValid ? Color("CookiesButtonText") : Color("CookiesTextPrimary").opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .frame(height: 55)
                        .background(isFormValid ? Color("CookiesButtonFill") : Color("CookiesSurface"))
                        .clipShape(Capsule())
                }
                    .disabled(!isFormValid || authViewModel.isLoading)

                    HStack(spacing: 4) {
                        Text("Terms of Service")
                            .underline()
                        Text("&")
                        Text("Privacy Policy")
                            .underline()
                    }
                    .font(.caption)
                    .foregroundColor(Color("CookiesTextSecondary"))
                    .padding(.bottom, 10)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .navigationBarHidden(true)
        .onChange(of: authViewModel.isCodeSent) { _, newValue in
            if newValue {
                showVerification = true
            }
        }
        .onAppear {
            authViewModel.isCodeSent = false
            AnalyticsManager.logScreen("PhoneEntry", className: "SignInWithPhoneNumberView")
        }
        .onChange(of: authViewModel.errorMessage) { _, newValue in
            if let message = newValue {
                activeAlertMessage = message
            }
        }
        .navigationDestination(isPresented: $showVerification) {
            VerificationCodeView(displayPhoneNumber: formattedPhone)
        }
        .alert("Error", isPresented: Binding(
            get: { activeAlertMessage != nil },
            set: { _ in activeAlertMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(activeAlertMessage ?? "Something went wrong.")
        }
    }
}

struct VerificationCodeView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var code: String = ""
    @FocusState private var isFocused: Bool
    @State private var timeRemaining = 25
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var activeAlertMessage: String?

    let displayPhoneNumber: String

    var body: some View {
        ZStack {
            Color("CookiesBackground")
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color("CookiesTextPrimary"))
                        .padding(12)
                        .background(Color("CookiesSurface"))
                        .clipShape(Circle())
                }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    Text("We sent you a \nverification code")
                        .font(.system(size: 30, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color("CookiesTextPrimary"))

                    ZStack {
                        TextField("", text: $code)
                            .keyboardType(.numberPad)
                            .focused($isFocused)
                            .textContentType(.oneTimeCode)
                            .onChange(of: code) { _, newValue in
                                if newValue.count > 6 {
                                    code = String(newValue.prefix(6))
                                }
                            }
                            .opacity(0)

                        HStack(spacing: 10) {
                            ForEach(0..<6, id: \.self) { index in
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color("CookiesSurface"))

                                    if index == code.count {
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color("CookiesAccent"), lineWidth: 1)
                                    }

                                    if index < code.count {
                                        let indexStr = code.index(code.startIndex, offsetBy: index)
                                        Text(String(code[indexStr]))
                                            .font(.title)
                                            .fontWeight(.semibold)
                                            .foregroundColor(Color("CookiesTextPrimary"))
                                    }

                                    if index == code.count && isFocused {
                                        Rectangle()
                                            .fill(Color("CookiesAccent"))
                                            .frame(width: 2, height: 20)
                                            .opacity(0.5)
                                    }
                                }
                                .frame(width: 45, height: 55)
                            }
                        }
                    }
                    .padding(.horizontal)

                    VStack(spacing: 4) {
                        Text("Enter the 6-digit code sent to")
                            .foregroundColor(Color("CookiesTextSecondary"))
                        Text(displayPhoneNumber.isEmpty ? "+1 (555) 123-4567" : displayPhoneNumber)
                            .foregroundColor(Color("CookiesTextPrimary"))
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 20) {
                    Text("Resend code in \(timeRemaining)s")
                        .font(.subheadline)
                        .foregroundColor(Color("CookiesTextPrimary"))
                        .onReceive(timer) { _ in
                            if timeRemaining > 0 {
                                timeRemaining -= 1
                            }
                        }

                    Button(action: {
                        authViewModel.verifyCode(code)
                    }) {
                        Text("Verify")
                            .font(.headline)
                            .foregroundColor(code.count == 6 ? Color("CookiesButtonText") : Color("CookiesTextPrimary").opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .frame(height: 55)
                            .background(code.count == 6 ? Color("CookiesButtonFill") : Color("CookiesSurface"))
                            .clipShape(Capsule())
                    }
                    .disabled(code.count != 6 || authViewModel.isLoading)

                    Spacer().frame(height: 10)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFocused = true
            }
            AnalyticsManager.logScreen("VerificationCode", className: "VerificationCodeView")
        }
        .onChange(of: authViewModel.errorMessage) { _, newValue in
            if let message = newValue {
                activeAlertMessage = message
            }
        }
        .alert("Error", isPresented: Binding(
            get: { activeAlertMessage != nil },
            set: { _ in activeAlertMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(activeAlertMessage ?? "Something went wrong.")
        }
        .navigationBarHidden(true)
    }
}

struct WelcomeView: View {
    let onContinue: () -> Void
    let onNoCookie: () -> Void

    var body: some View {
        ZStack {
            Image("welcome_screen")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .edgesIgnoringSafeArea(.all)

            VStack {
                Spacer()
                LinearGradient(
                    gradient: Gradient(colors: [.clear, Color("Lead").opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 300)
            }
            .edgesIgnoringSafeArea(.bottom)

            VStack {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color("Snow"), lineWidth: 2)
                            .frame(width: 36, height: 36)
                        Image(systemName: "square.dashed")
                            .foregroundColor(Color("Snow"))
                            .font(.system(size: 20))
                    }
                    Text("Cookies")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color("Snow"))
                        .tracking(2)
                }
                .padding(.top, 50)

                Spacer()

                VStack(spacing: 4) {
                    Text("Make your phone")
                    Text("a tool again")
                }
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(Color("Snow"))
                .multilineTextAlignment(.center)
                .padding(.bottom, 30)

                VStack(spacing: 16) {
                    Button(action: {
                        onContinue()
                        AnalyticsManager.logEvent("welcome_continue")
                    }) {
                        Text("Continue with Phone Number")
                            .font(.headline)
                            .foregroundColor(Color("Lead"))
                            .frame(maxWidth: 330)
                            .padding()
                            .background(Color("Snow"))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 25)
                    .padding(.bottom, 10)

                    Button(action: {
                        onNoCookie()
                        AnalyticsManager.logEvent("welcome_no_cookie")
                    }) {
                        Text("I Dont Have Cookies")
                            .font(.headline)
                            .foregroundColor(Color("Lead"))
                            .frame(maxWidth: 330)
                            .padding()
                            .background(Color("Snow"))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 25)
                    .padding(.bottom, 50)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 10)
            }
        }
        .statusBar(hidden: true)
    }
}

private extension SignInWithPhoneNumberView {
    func formatForDisplay(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        guard !digits.isEmpty else { return "" }

        let trimmed = digits.count > 10 ? String(digits.prefix(10)) : digits
        let chars = Array(trimmed)

        var result = ""
        if chars.count > 0 {
            result += "("
            result += String(chars.prefix(3))
        }
        if chars.count >= 3 {
            result += ") "
            if chars.count > 3 {
                result += String(chars[3..<min(chars.count, 6)])
            }
        }
        if chars.count >= 6 {
            result += "-"
            if chars.count > 6 {
                result += String(chars[6..<chars.count])
            }
        }

        return result
    }
}

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView()
            .environmentObject(AuthViewModel())
    }
}
