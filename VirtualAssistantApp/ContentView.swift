//
//  ContentView.swift
//  VirtualAssistantApp
//
//  Created by Šimun Mikecin on 25/10/2019.
//  Copyright © 2019 KANTA d.o.o. All rights reserved.
//

import EventKit
import SwiftUI

struct ContentView: View {
  @EnvironmentObject var settings: UserSettings
  @State private var recording = false
  @State private var processing = false

  @State private var balance = "23.45"
  @State private var bankerPhoneNumber = "091123456"
  @State private var callCenterPhoneNumber = "0919876543"

  func initialized() -> Bool {
    return settings.assistant != nil
  }
  var body: some View {
    NavigationView {
      VStack {
        Spacer()
        Spacer()
        Text(initialized() ? "What can I help you with?" : "Initializing, please wait...")
          .bold()
          .font(.title)
        Text(initialized() ? "USAGE" : "")
          .font(.body)
          .frame(minWidth: 0, idealWidth: .infinity, maxWidth: .infinity, minHeight: 0, idealHeight: .infinity, maxHeight: .infinity, alignment: .center)
        Text(recording ? "Go ahead, I’m listening…" : "")
        Button(action: {
          do {
            if self.recording {
              try self.settings.assistant!.stopListening()
              self.recording = false
              self.processing = true
            } else {
              self.recording = true
              try self.settings.assistant!.listen(afterProcessingQueue: DispatchQueue.global(qos: .userInteractive)) {result in
                self.recording = false
                #if DEBUG
                print("intent=\(String(describing: result?.intent))")
                #endif
                if result == nil {
                  self.settings.assistant!.speak(utterance: NSLocalizedString("Could you please repeat.", comment: ""), immediate: false, whenFinishedQueue: DispatchQueue.global(qos: .userInitiated)) { _ in
                    self.processing = false
                  }
                  return
                }
                switch result!.intent {
                  case "accountBalance":
                  let utterance = String.localizedStringWithFormat(NSLocalizedString("On your account, you have %@ EUR", comment: ""), String(self.balance))
                  self.settings.assistant!.speak(utterance: utterance, immediate: false, whenFinishedQueue: DispatchQueue.global(qos: .userInitiated)) { _ in
                    self.processing = false
                  }
                case "call":
                  let who0 = result!.entities["who"]
                  if who0 == nil {
                    self.settings.assistant!.speak(utterance: NSLocalizedString("Could you please repeat.", comment: ""), immediate: false, whenFinishedQueue: DispatchQueue.global(qos: .userInitiated)) { _ in
                      self.processing = false
                    }
                    break
                  }
                  let who = who0 as! String
                  let url = URL(string: "tel://\(who.contains("banker") ? self.bankerPhoneNumber : self.callCenterPhoneNumber)")
                    DispatchQueue.main.async {
                      UIApplication.shared.open(url!, options: [:], completionHandler: nil)
                    }
                    self.processing = false
                  case "newCalendarEvent":

                    // start receiving events after the permission is granted
                    UserSettings.eventStore.reset()

                    if EKEventStore.authorizationStatus(for: .event) == .authorized {
                      #if DEBUG
                      print("Authorized for events.")
                      #endif
                      let when0 = result!.entities["when"]
                      if when0 == nil {
                        fallthrough
                      }
                      let when = when0 as! Date

                      let event = EKEvent(eventStore: UserSettings.eventStore)
                      event.startDate = when
                      event.endDate = when.addingTimeInterval(3600)
                      event.title = NSLocalizedString("Meeting", comment: "")
                      event.calendar = UserSettings.eventStore.defaultCalendarForNewEvents
                      if event.calendar == nil {
                        let calendars = UserSettings.eventStore.calendars(for: .event)
                        event.calendar = calendars.first
                      }
                      do {
                        try UserSettings.eventStore.save(event, span: .thisEvent)
                        try UserSettings.eventStore.commit()
                        self.settings.assistant!.speak(utterance: NSLocalizedString("Appointment added.", comment: ""), immediate: false, whenFinishedQueue: DispatchQueue.global(qos: .userInitiated)) { _ in
                          self.processing = false
                        }
                      } catch let error {
                        #if DEBUG
                        print("calendar error=\(error.localizedDescription)")
                        #endif
                        self.settings.assistant!.speak(utterance: error.localizedDescription, immediate: false, whenFinishedQueue: DispatchQueue.global(qos: .userInitiated)) { _ in
                          self.processing = false
                        }
                      }
                    } else {
                      #if DEBUG
                      print("Not authorized for events.")
                      #endif
                      self.settings.assistant!.speak(utterance: NSLocalizedString("This feature requires access rights for calendar events. Please grant access.", comment: ""), immediate: false, whenFinishedQueue: DispatchQueue.global(qos: .userInitiated)) { _ in
                        self.processing = false
                      }
                    }
                  default:
                    self.settings.assistant!.speak(utterance: NSLocalizedString("Could you please repeat.", comment: ""), immediate: false, whenFinishedQueue: DispatchQueue.global(qos: .userInitiated)) { _ in
                      self.processing = false
                    }
                    return
                }
              }
            }
          } catch {
            self.processing = false
            self.recording = false
          }
        }) {
          Text(initialized() ? (processing ? "Processing...": (recording ? "◾" : "🔴")) : "")
            .font(.largeTitle)
        }
        .disabled(!initialized() || processing)
      }
      .navigationBarTitle(Text("Virtual Assistant"), displayMode: .inline)
      .navigationBarItems(trailing:
        Button(action: {
          let alertController = UIAlertController(title: NSLocalizedString("Parameters", comment: ""), message: nil, preferredStyle: .alert)
          alertController.addTextField { (textField: UITextField) in
            textField.placeholder = NSLocalizedString("Current account balance in EUR", comment: "")
            textField.text = self.balance
          }
          alertController.addTextField { (textField: UITextField) in
            textField.placeholder = NSLocalizedString("Call center phone number", comment: "")
            textField.text = self.callCenterPhoneNumber
          }
          let ok = UIAlertAction(title: "OK", style: .default) { (UIAlertAction) in
            let value = alertController.textFields?.first?.text
            if value != nil {
              let amount = Decimal(string: value!)
              if amount != nil {
                var amount1 = amount!
                var result: Decimal = 0
                NSDecimalRound(&result, &amount1, 2, .bankers)
                self.balance = NSDecimalString(&result, nil)
              }
            }
            let callCenterPhoneNumber = alertController.textFields?[1].text
            if callCenterPhoneNumber != nil && !callCenterPhoneNumber!.isEmpty {
              self.callCenterPhoneNumber = callCenterPhoneNumber!
            }
          }
          let cancel = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { (UIAlertAction) in
          }
          alertController.addAction(ok)
          alertController.addAction(cancel)
          showAlert(alert: alertController)
        }, label: {
          Text("⚙")
        })
      )
    }
  }
}

func showAlert(alert: UIAlertController) {
  if let controller = topMostViewController() {
    controller.present(alert, animated: true)
  }
}

private func keyWindow() -> UIWindow? {
  return UIApplication.shared.connectedScenes
    .filter {$0.activationState == .foregroundActive}
    .compactMap {$0 as? UIWindowScene}
    .first?.windows.filter {$0.isKeyWindow}.first
}

private func topMostViewController() -> UIViewController? {
  guard let rootController = keyWindow()?.rootViewController else {
    return nil
  }
  return topMostViewController(for: rootController)
}

private func topMostViewController(for controller: UIViewController) -> UIViewController {
  if let presentedController = controller.presentedViewController {
    return topMostViewController(for: presentedController)
  } else if let navigationController = controller as? UINavigationController {
    guard let topController = navigationController.topViewController else {
      return navigationController
    }
    return topMostViewController(for: topController)
  } else if let tabController = controller as? UITabBarController {
    guard let topController = tabController.selectedViewController else {
      return tabController
    }
    return topMostViewController(for: topController)
  }
  return controller
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      ContentView()
        .environmentObject(UserSettings())
      ContentView()
        .environmentObject(UserSettings())
        .environment(\.sizeCategory, .extraExtraExtraLarge)
      ContentView()
        .environmentObject(UserSettings())
        .environment(\.colorScheme, .dark)
      ContentView()
        .environmentObject(UserSettings())
        .environment(\.locale, Locale(identifier: "hr"))
    }
  }
}
#endif
