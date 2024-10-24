//
//  ContentView.swift
//  TranslateMe
//
//  Created by Chrisopher Franco on 10/23/24.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore

struct Translation: Identifiable {
    let id: String
    let original: String
    let translated: String
}

struct ContentView: View {
    // State variables
    @State private var inputText = ""
    @State private var translatedText = ""
    @State private var history = [Translation]() // Array to hold translations

    var body: some View {
        VStack {
            // Input field for text to be translated
            TextField("Enter text to translate", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            // Button to translate text
            Button("Translate") {
                translateText(inputText) // Call translation function
            }
            .padding()

            // Display translated text
            Text(translatedText)
                .padding()

            // ScrollView to display translation history
            ScrollView {
                ForEach(history, id: \.id) { translation in
                    VStack(alignment: .leading) {
                        Text("Original: \(translation.original)")
                        Text("Translated: \(translation.translated)")
                    }
                    .padding()
                }
            }

            // Button to clear translation history
            Button("Clear History") {
                clearHistory() // Call clear history function
            }
            .padding()
        }
        .onAppear(perform: loadHistory) // Load history on view load
    }

    // Step 3: Translate text using MyMemory API via URLSession
    func translateText(_ text: String) {
        let sourceLang = "en" // Source language
        let targetLang = "es" // Target language (you can change this)
        let urlString = "https://api.mymemory.translated.net/get?q=\(text)&langpair=\(sourceLang)|\(targetLang)"
        
        // Encode the URL to handle special characters
        guard let encodedURL = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedURL) else {
            print("Invalid URL")
            return
        }

        // Perform the request using URLSession
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                return
            }

            if let data = data {
                do {
                    // Parse the JSON response
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let responseData = json["responseData"] as? [String: Any],
                       let translated = responseData["translatedText"] as? String {
                        // Update the UI on the main thread
                        DispatchQueue.main.async {
                            self.translatedText = translated // Update translated text
                            saveTranslation(original: text, translated: translated) // Save to Firestore
                        }
                    }
                } catch {
                    print("JSON Parsing Error: \(error)")
                }
            }
        }
        task.resume()
    }

    // Step 4: Save translated text to Firebase Firestore
    func saveTranslation(original: String, translated: String) {
        let db = Firestore.firestore()
        db.collection("translations").addDocument(data: [
            "originalText": original,
            "translatedText": translated,
            "timestamp": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error saving translation: \(error)")
            } else {
                loadHistory() // Reload history after saving a new translation
            }
        }
    }

    // Step 4: Load translation history from Firestore
    func loadHistory() {
        let db = Firestore.firestore()
        db.collection("translations").order(by: "timestamp").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching translations: \(error)")
            } else {
                var newHistory = [Translation]()
                for document in snapshot!.documents {
                    let original = document.get("originalText") as? String ?? ""
                    let translated = document.get("translatedText") as? String ?? ""
                    let id = document.documentID
                    newHistory.append(Translation(id: id, original: original, translated: translated))
                }
                self.history = newHistory // Update the history state
            }
        }
    }

    // Step 5: Clear translation history from Firestore
    func clearHistory() {
        let db = Firestore.firestore()
        db.collection("translations").getDocuments { snapshot, error in
            if let error = error {
                print("Error deleting history: \(error)")
            } else {
                for document in snapshot!.documents {
                    document.reference.delete() // Delete each document
                }
                self.history = [] // Clear local history state
            }
        }
    }
}
