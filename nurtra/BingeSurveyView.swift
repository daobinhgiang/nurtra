//
//  BingeSurveyView.swift
//  Nurtra V2
//
//  Created by AI Assistant on 10/27/25.
//

import SwiftUI

struct BingeSurveyView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @StateObject private var firestoreManager = FirestoreManager()
    let onComplete: () -> Void

    @State private var step: Int = 0
    @State private var isSubmitting = false

    // Focus for text fields
    private enum FocusedField: Hashable {
        case feelingsOther
        case triggersOther
        case nextTimeOther
    }
    @FocusState private var focusedField: FocusedField?

    // Step 1: How do you feel?
    private let feelingsOptions = ["Guilty", "Ashamed", "Anxious", "Sad", "Numb", "Stressed"]
    @State private var selectedFeelings: Set<String> = []
    @State private var feelingsOtherText: String = ""

    // Step 2: What led you to the binge?
    private let triggersOptions = ["Stress", "Boredom", "Loneliness", "Fatigue", "Social pressure", "Restricting earlier"]
    @State private var selectedTriggers: Set<String> = []
    @State private var triggersOtherText: String = ""

    // Step 3: What would you have done differently next time?
    private let nextTimeOptions = ["Call a friend", "Go for a walk", "Have a balanced snack", "Journal feelings", "Practice mindfulness", "Delay 10 minutes"]
    @State private var selectedNextTime: Set<String> = []
    @State private var nextTimeOtherText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(titleForStep(step))
                    .font(.title2)
                    .fontWeight(.semibold)
                ProgressView(value: Double(step + 1), total: 3)
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture { dismissKeyboard() }

            // Content
            TabView(selection: $step) {
                surveySlide(
                    prompt: "How do you feel?",
                    options: feelingsOptions,
                    selections: $selectedFeelings,
                    otherText: $feelingsOtherText,
                    focus: .feelingsOther
                )
                .tag(0)

                surveySlide(
                    prompt: "What led you to the binge?",
                    options: triggersOptions,
                    selections: $selectedTriggers,
                    otherText: $triggersOtherText,
                    focus: .triggersOther
                )
                .tag(1)

                surveySlide(
                    prompt: "What would you have done differently next time?",
                    options: nextTimeOptions,
                    selections: $selectedNextTime,
                    otherText: $nextTimeOtherText,
                    focus: .nextTimeOther
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Navigation buttons
            HStack {
                if step > 0 {
                    Button("Back") {
                        dismissKeyboard()
                        withAnimation { step -= 1 }
                    }
                    .buttonStyle(SecondaryCapsuleStyle())
                }

                Spacer()

                if step < 2 {
                    Button("Next") {
                        dismissKeyboard()
                        withAnimation { step += 1 }
                    }
                    .buttonStyle(PrimaryCapsuleStyle())
                } else {
                    Button("Submit") {
                        dismissKeyboard()
                        Task {
                            await submitSurvey()
                        }
                    }
                    .buttonStyle(PrimaryCapsuleStyle())
                    .disabled(isSubmitting)
                }
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture { dismissKeyboard() }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Binge Survey")
        .contentShape(Rectangle())
        .onTapGesture { dismissKeyboard() }
    }

    private func titleForStep(_ step: Int) -> String {
        switch step {
        case 0: return "How do you feel?"
        case 1: return "What led to the binge?"
        default: return "Next time, I could…"
        }
    }

    @ViewBuilder
    private func surveySlide(
        prompt: String,
        options: [String],
        selections: Binding<Set<String>>,
        otherText: Binding<String>,
        focus: FocusedField
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(prompt)
                    .font(.headline)

                // Vertical full-width option rows
                VStack(spacing: 10) {
                    ForEach(options, id: \.self) { option in
                        let isSelected = selections.wrappedValue.contains(option)
                        Button {
                            if isSelected {
                                selections.wrappedValue.remove(option)
                            } else {
                                selections.wrappedValue.insert(option)
                            }
                            dismissKeyboard()
                        } label: {
                            HStack {
                                Text(option)
                                    .font(.body)
                                    .foregroundColor(isSelected ? .white : .primary)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.white)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(isSelected ? Color.blue : Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    // Other free text as the last full-width row
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Other")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // Box-styled container for the text field
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.systemGray6))
                            TextField("Type here…", text: otherText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .focused($focusedField, equals: focus)
                        }
                        .frame(maxWidth: .infinity)
                        .onTapGesture {
                            focusedField = focus
                        }
                    }
                }
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture { dismissKeyboard() }
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
    }
    
    private func submitSurvey() async {
        isSubmitting = true
        
        // Collect all responses
        let allFeelings = Array(selectedFeelings) + (feelingsOtherText.isEmpty ? [] : [feelingsOtherText])
        let allTriggers = Array(selectedTriggers) + (triggersOtherText.isEmpty ? [] : [triggersOtherText])
        let allNextTime = Array(selectedNextTime) + (nextTimeOtherText.isEmpty ? [] : [nextTimeOtherText])
        
        let responses = BingeSurveyResponses(
            feelings: allFeelings,
            triggers: allTriggers,
            nextTime: allNextTime,
            submittedAt: Date()
        )
        
        do {
            // Check if this is the first survey BEFORE saving
            let isFirstSurvey = !authManager.hasCompletedFirstBingeSurvey
            
            // Save to Firestore
            try await firestoreManager.saveBingeSurvey(responses: responses)
            
            // Update local auth manager state
            if isFirstSurvey {
                authManager.markFirstBingeSurveyComplete()
                
                // Trigger paywall for first binge survey
                subscriptionManager.showPaywall(for: "first_binge_survey")
            }
            
            // Dismiss this view
            dismiss()
            
            // Then trigger the parent to dismiss too
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                onComplete()
            }
        } catch {
            print("❌ Error saving binge survey: \(error)")
            isSubmitting = false
        }
    }
}

// Simple capsule button styles
struct PrimaryCapsuleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Color.blue)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

struct SecondaryCapsuleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.blue)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Color.blue.opacity(0.12))
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}
