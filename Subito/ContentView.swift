//
//  ContentView.swift
//  Subito
//
//  Created by Scott Odle on 9/8/20.
//  Copyright © 2020 Scott Odle. All rights reserved.
//

import SwiftUI


struct LoginView: View {
    @EnvironmentObject var viewState: ViewState
    
    @State var username = ""
    @State var password = ""
    
    var body: some View {
        VStack {
            TextField("Username", text: $username)
            SecureField("Password", text: $password)
            Button("Log In") {
                logIn(username: username, password: password) { success in
                    print(success)
                    if (success) {
                        viewState.sessionState = .loading
                    } else {
                        viewState.sessionState = .loggedOut
                    }
                }
            }
        }
    }
}


struct LoadingView: View {
    @EnvironmentObject var viewState: ViewState
    
    var body: some View {
        Text("Loading...").onAppear {
            checkSessionState { result in
                viewState.sessionState = result
            }
        }
    }
}


struct SecurityQuestionView: View {
    @EnvironmentObject var viewState: ViewState
    
    @State var securityQuestionText = "Loading security question..."
    @State var securityQuestionId = -1
    @State var securityQuestionAnswer = ""
    
    var body: some View {
        VStack {
            Text("Security Question")
            Text(securityQuestionText)
            SecureField("Answer", text: $securityQuestionAnswer)
            Button("Submit") {
                answerSecurityQuestion(
                    questionId: securityQuestionId,
                    answer: securityQuestionAnswer
                ) { success in
                    if (success) {
                        viewState.sessionState = .loading
                    } else {
                        securityQuestionAnswer = ""
                    }
                }
            }
        }.onAppear {
            getSecurityQuestion { result in
                guard let question = result else {
                    viewState.sessionState = .loading
                    return
                }
                
                securityQuestionText = question.text
                securityQuestionId = question.challengeQuestionKey
            }
        }
    }
}

struct LoggedInView: View {
    @State var pin = ""
    @State var startDelay = "0"
    @State var runTime = "10"
    @State var climateF = "72"
    
    @State var requestPending = false
    
    var body: some View {
        VStack {
            Text("Subito (Subaru STARLINK Remote Services Client)")
            HStack {
                Text("PIN:")
                SecureField("PIN", text: $pin).keyboardType(.numberPad)
            }
            HStack {
                Text("Start Delay (minutes):")
                TextField("Start Delay (minutes)", text: $startDelay).keyboardType(.numberPad)
            }
            HStack {
                Text("Run Time (minutes):")
                TextField("Run Time (minutes)", text: $runTime).keyboardType(.numberPad)
            }
            HStack {
                Text("Thermostat (F):")
                TextField("Thermostat (F)", text: $climateF).keyboardType(.numberPad)
            }
            HStack {
                Button("Start Engine") {
                    requestPending = true
                    startEngine(pin: pin, delay: startDelay, runTime: runTime, climate: climateF) {
                        requestPending = false
                    }
                }.disabled(requestPending)
                Button("Stop Engine") {
                    requestPending = true
                    stopEngine(pin: pin) {
                        requestPending = false
                    }
                }.disabled(requestPending)
            }
            HStack {
                Button("Lock Doors") {
                    requestPending = true
                    lockDoors(pin: pin) {
                        requestPending = false
                    }
                }.disabled(requestPending)
                Button("Unlock Doors") {
                    requestPending = true
                    unlockDoors (pin: pin) {
                        requestPending = false
                    }
                }.disabled(requestPending)
            }
        }
    }
}


struct ContentView: View {
    @EnvironmentObject var viewState: ViewState
    
    var body: some View {
        switch (viewState.sessionState) {
        case .loading:
            LoadingView()
        case .loggedOut:
            LoginView()
        case .needSecurityQuestion:
            SecurityQuestionView()
        case .loggedIn:
            LoggedInView()
        default:
            Text(viewState.sessionState.rawValue)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
