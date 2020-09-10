//
//  SubaruClient.swift
//  Subito
//
//  Created by Scott Odle on 9/9/20.
//  Copyright © 2020 Scott Odle. All rights reserved.
//

import UIKit

import Alamofire
import KeychainSwift

enum SubaruSessionState: String {
    case loading = "Loading..."
    case loggedOut = "Logged out."
    case needSecurityQuestion = "Need to answer security question."
    case loggedIn = "Logged in."
    case error = "An error occurred while logging in."
}

struct SubaruSecurityQuestion {
    var challengeQuestionKey: Int
    var groupNum: Int
    var text: String
}

let session = Session(redirectHandler: Redirector(behavior: .doNotFollow))
let sessionTokenKeyName = "SubaruSessionToken"
let deviceId = UIDevice.current.identifierForVendor!.uuidString

func checkSessionState(onDone: @escaping (SubaruSessionState) -> Void) -> Void {
    guard let token = KeychainSwift().get(sessionTokenKeyName) else {
        return onDone(.loggedOut)
    }
    
    guard let cookie = HTTPCookie(properties: [
        .domain: "www.mysubaru.com",
        .path: "/",
        .name: "JSESSIONID",
        .value: token,
        .secure: "TRUE"
    ]) else {
        print("Couldn't set session cookie!")
        return onDone(.error)
    }
    session.sessionConfiguration.httpCookieStorage?.setCookie(cookie)
    
    session.request("https://www.mysubaru.com/profile/verifyDeviceAuthentication.json",
                    method: .get,
                    parameters: [
                        "deviceId": deviceId
                    ]
    ).responseJSON { response in
        debugPrint(response)
        
        if response.response?.statusCode == 302 {
            return onDone(.loggedOut)
        }
        
        guard let result = response.value else {
            print("Failed to retrieve response value!")
            return onDone(.error)
        }
        
        guard let JSON = result as? NSDictionary else {
            print("Failed to parse response value!")
            return onDone(.error)
        }
        
        guard let success = JSON.object(forKey: "success") as? Bool else {
            print("Response missing \"success\" key!")
            return onDone(.error)
        }
        
        if (success) {
            onDone(.loggedIn)
        } else {
            onDone(.needSecurityQuestion)
        }
    }
}

func logIn(username: String, password: String, onDone: @escaping (Bool) -> Void) -> Void {
    session.request("https://www.mysubaru.com/login",
                    method: .post,
                    parameters: [
                        "username": username,
                        "password": password,
                        "deviceId": deviceId
                    ]
    ).response { response in
        debugPrint(response)
        
        guard let header = response.response?.allHeaderFields as? [String: String] else {
            print("Couldn't get response headers!")
            return onDone(false)
        }
        
        guard let url = response.request?.url else {
            print("Couldn't parse request URL!")
            return onDone(false)
        }
        
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: header, for: url)
        for cookie in cookies {
            print(cookie.name)
            if (cookie.name == "JSESSIONID") {
                KeychainSwift().set(cookie.value, forKey: sessionTokenKeyName, withAccess: .accessibleAfterFirstUnlockThisDeviceOnly)
                return onDone(true)
            }
        }
        return onDone(false)
    }
}

func getSecurityQuestion(onDone: @escaping (SubaruSecurityQuestion?) -> Void) -> Void {
    session.request("https://www.mysubaru.com/profile/getSecurityQuestion.json",
                    method: .get,
                    parameters: [
                        "deviceId": deviceId
                    ]
    ).responseJSON { response in
        debugPrint(response)
        
        guard let result = response.value else {
            print("Failed to retrieve response value!")
            return onDone(nil)
        }
        
        guard let JSON = result as? NSDictionary else {
            print("Failed to parse response value!")
            return onDone(nil)
        }
        
        guard let challengeQuestionKey = JSON.object(forKey: "challengeQuestionKey") as? Int else {
            print("Failed to get challengeQuestionKey!")
            return onDone(nil)
        }
        
        guard let groupNum = JSON.object(forKey: "groupNum") as? Int else {
            print("Failed to get groupNum!")
            return onDone(nil)
        }
        
        guard let text = JSON.object(forKey: "text") as? String else {
            print("Failed to get text!")
            return onDone(nil)
        }
        
        return onDone(
            SubaruSecurityQuestion(
                challengeQuestionKey: challengeQuestionKey,
                groupNum: groupNum,
                text: text
            )
        )
    }
}

func answerSecurityQuestion(questionId: Int, answer: String, onDone: @escaping (Bool) -> Void ) -> Void {
    session.request("https://www.mysubaru.com/account/securityAnswer.json",
                    method: .post,
                    parameters: [
                        "questionId": questionId,
                        "answer": answer,
                        "deviceName": "Subito",
                        "deviceId": deviceId
                    ]
    ).responseJSON { response in
        debugPrint(response)
        
        guard let result = response.value else {
            print("Failed to retrieve response value!")
            return onDone(false)
        }
        
        guard let success = result as? Bool else {
            print("Failed to parse response value!")
            return onDone(false)
        }
        
        return onDone(success)
    }
}

func startEngine(pin: String, delay: String, runTime: String, climate: String, onDone: @escaping () -> Void) -> Void {
    session.request("https://www.mysubaru.com/service/g2/engineStart/execute.json",
                    method: .post,
                    parameters: [
                        "pin": pin,
                        "delay": delay,
                        "horn": "true",
                        "unlockDoorType": "FRONT_LEFT_DOOR_CMD",
                        "runtimeMinutes": runTime,
                        "startConfiguration": "START_ENGINE_ALLOW_KEY_IN_IGNITION",
                        "climateSettings": "on",
                        "climateZoneFrontTemp": climate
                    ]
    ).response { response in
        debugPrint(response)
        
        onDone()
    }
}

func stopEngine(pin: String, onDone: @escaping () -> Void) -> Void {
    session.request("https://www.mysubaru.com/service/g2/engineStop/execute.json",
                    method: .post,
                    parameters: [
                        "pin": pin
                    ]
    ).response { response in
        debugPrint(response)
        
        onDone()
    }
}

func lockDoors(pin: String, onDone: @escaping () -> Void) -> Void {
    session.request("https://www.mysubaru.com/service/g2/lock/execute.json",
                    method: .post,
                    parameters: [
                        "pin": pin
                    ]
    ).response { response in
        debugPrint(response)
        
        onDone()
    }
}

func unlockDoors(pin: String, onDone: @escaping () -> Void) -> Void {
    session.request("https://www.mysubaru.com/service/g2/unlock/execute.json",
                    method: .post,
                    parameters: [
                        "pin": pin,
                        "unlockDoorType": "ALL_DOORS_CMD"
                    ]
    ).response { response in
        debugPrint(response)
        
        onDone()
    }
}
