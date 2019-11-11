//
//  UserSettings.swift
//  VirtualAssistantApp
//
//  Created by Šimun Mikecin on 29/10/2019.
//  Copyright © 2019 KANTA d.o.o. All rights reserved.
//

import AVFoundation
import EventKit
import VirtualAssistantKit
import Foundation

class UserSettings: ObservableObject {
  @Published var assistant: Assistant? = nil
  static public let eventStore: EKEventStore = {
    let instance = EKEventStore()

    instance.requestAccess(to: .event) { (granted: Bool, error: Error?) in
      #if DEBUG
      print("granted=\(granted) error=\(error.debugDescription)")
      #endif
      }
    return instance
  }()
  init() {
    #if DEBUG
    print("LUModel initialization...")
    #endif
    let initGroup = DispatchGroup()
    initGroup.enter()
    initGroup.enter()
    let language = Locale.current.languageCode
    let croatian = language?.hasPrefix("hr") ?? false
    let languageUnderstandingModel = LanguageUnderstandingModel(name: croatian ? "622C8B06-A049-4935-9475-372212BDE5AF" : "D85AE6A0-F447-4A92-8466-CE985E82A766", onlyOnDevice: false, afterInitializationQueue: DispatchQueue.global()) { ok in
      #if DEBUG
      print("LUModel initialized.ok=\(ok)")
      #endif
      initGroup.leave()
    }
    print("SSModel initialization...")
    let speechSynthesisModel = SpeechSynthesisModel(name: croatian ? "9FF08A25-69C3-4F19-A03B-9732DAEBF76F" : "FC9D5CDF-7CDC-46DA-A53A-CA0F60FC3ABD", onlyOnDevice: false, afterInitializationQueue: DispatchQueue.global()) {_ in
      #if DEBUG
      print("SSModel initialized.")
      #endif
      initGroup.leave()
    }
    initGroup.notify(queue: DispatchQueue.main) {
      #if DEBUG
      print("Models initialized.")
      #endif
      self.assistant = Assistant(languageUnderstandingModel: languageUnderstandingModel, speechSynthesisModel: speechSynthesisModel)
      UserSettings.eventStore.reset()
    }
  }
}
