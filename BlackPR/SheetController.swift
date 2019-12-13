//
//  SheetController.swift
//  BlackPR
//
//  Created by migmit on 2019. 11. 19..
//  Copyright © 2019. migmit. All rights reserved.
//

import Cocoa
import WebKit

class SheetController: NSViewController, WKNavigationDelegate {
    
    var delegate: AuthCodeDelegate?

    @IBOutlet weak var LoginView: WKWebView!
    
    let codePrefix = "code="
    let statePrefix = "state="
    let clientId = "48d2e93f4bc7ffc4bbb1"
    let awsEndpoint = "https://mzq23634v9.execute-api.eu-west-1.amazonaws.com/default"
    
    func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
    func startFromBeginning() {
        let text = "<body onload='window.location.href = &quot;https://github.com/login/oauth/authorize?client_id=48d2e93f4bc7ffc4bbb1&amp;state=\(randomString(length: 20))&amp;scope=read:user,notifications,repo&quot;'>Redirecting to GitHub...</body>"
        let pool = WKProcessPool()
        let configuration = WKWebViewConfiguration()
        configuration.processPool = pool
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        let newLoginView = WKWebView(frame: LoginView.frame, configuration: configuration)
        newLoginView.navigationDelegate = LoginView.navigationDelegate
        view.replaceSubview(LoginView, with: newLoginView)
        LoginView = newLoginView
        DispatchQueue.main.async {
            self.LoginView.loadHTMLString(text, baseURL: nil)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        startFromBeginning()
    }
    
    override func cancelOperation(_ sender: Any?) {
        dismiss(nil)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if (navigationAction.request.url?.scheme == "com.kinja.blackpr") {
            decisionHandler(.cancel)
            if let query = navigationAction.request.url?.query {
                let params = query.split(separator: "&")
                if let codeLine = params.first(where: {$0.hasPrefix(codePrefix)}),
                    let stateLine = params.first(where: {$0.hasPrefix(statePrefix)}) {
                    let code = String(codeLine.dropFirst(codePrefix.count))
                    let state = String(stateLine.dropFirst(statePrefix.count))
                    let url = URL(string: "\(awsEndpoint)?client_id=\(clientId)&code=\(code)&state=\(state)")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Accept")
                    URLSession(configuration: .ephemeral).dataTask(with: request) {(data, response, error) in
                        if error == nil {
                            if let rawData = data,
                                let jsonData = try? JSONSerialization.jsonObject(with: rawData, options: []) as? [String:Any],
                                let token = jsonData["access_token"] as? String {
                                DispatchQueue.main.async {
                                    self.delegate?.accessTokenReceived(token: token)
                                    self.dismiss(nil)
                                }
                                return
                            }
                        }
                        DispatchQueue.main.async {
                            let alert = NSAlert()
                            alert.alertStyle = .critical
                            alert.messageText = "Authorization error"
                            alert.informativeText = "Something went wrong, going back"
                            alert.beginSheetModal(for: self.view.window!){_ in self.startFromBeginning()}
                        }
                    }.resume()
                }
            }
        } else {
            decisionHandler(.allow)
        }
    }
    
    @IBAction func cancelButtonClick(_ sender: NSButton) {
        dismiss(nil)
    }
}
