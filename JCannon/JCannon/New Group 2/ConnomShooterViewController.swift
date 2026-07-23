import UIKit
import WebKit
import AdjustSdk
import Reachability


final class ConnomShooterViewController: UIViewController {

    private var modes: Dochey?
    private var wkiv: WKWebView?
    private var apd: Shijian?
    
    override func loadView() {
        super.loadView()
        
        NotificationCenter.default.addObserver(self, selector: #selector(gaunchuzhesh), name: .kHanchu, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func gaunchuzhesh() {
        let dyuay: () -> Void = {
            self.setupIUS()
        }
        dyuay()
    }
    
    private func setupIUS() {
        if let aisy = Irionm.onmins() {
            modes = aisy
            
            Hviomn.shared.feiyue(from: aisy[DKey.fdreta] as? String ?? "")
            andOne(with: aisy)
            apd = Shijian(retags: aisy[DKey.aoidn] as? [String: String] ?? [:])
            andS(with: aisy)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        onyte()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        andTh()
    }

    override var shouldAutorotate: Bool { false }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    // MARK: - 搭建

    private func andOne(with config: Dochey) {
        guard let token = config[DKey.liomn] as? String else { return }
        
        let yugsas: () -> Void = {
            let das = ADJConfig(appToken: token, environment: ADJEnvironmentProduction)
            das?.delegate = self
            Adjust.initSdk(das)
        }
        yugsas()
        
    }

    private func andS(with config: Dochey) {
        let contentController = WKUserContentController()
        if let script = config[DKey.grtins] as? String {
            let userScript = WKUserScript(source: script,
                                          injectionTime: .atDocumentEnd,
                                          forMainFrameOnly: true)
            contentController.addUserScript(userScript)
        }
        contentController.add(self, name: Hviomn.shared.bry)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let web = WKWebView(frame: .zero, configuration: configuration)
        web.allowsBackForwardNavigationGestures = true
        web.uiDelegate = self
        web.navigationDelegate = self
        view.addSubview(web)
        wkiv = web

        if let target = config[DKey.duncm] as? String, let url = URL(string: target) {
            web.load(URLRequest(url: url))
        }
    }

    private func andTh() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let statusBarManager = scene.statusBarManager else { return }
        let topInset = statusBarManager.statusBarFrame.height
        let bottomInset = view.safeAreaInsets.bottom
        wkiv?.frame = CGRect(x: 0,
                                y: topInset,
                                width: view.bounds.width,
                                height: view.bounds.height - topInset - bottomInset)
    }
}

// MARK: - 导航与弹窗

extension ConnomShooterViewController: WKNavigationDelegate, WKUIDelegate {

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            UIApplication.shared.open(url)
        }
        return nil
    }
}

// MARK: - JS 桥

extension ConnomShooterViewController: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == Hviomn.shared.bry,
              let payload = message.body as? [String: String] else { return }
        apd?.zdjendd(payload)
    }
}


extension ConnomShooterViewController: AdjustDelegate {

    func adjustEventTrackingSucceeded(_ eventSuccessResponse: ADJEventSuccess?) {
        print(eventSuccessResponse as Any)
    }

    func adjustEventTrackingFailed(_ eventFailureResponse: ADJEventFailure?) {
        print(eventFailureResponse as Any)
    }
}


import Reachability
import AppTrackingTransparency


internal let kAppName =  "AppName"

class CannonStarViewController: UIViewController {
    
    lazy var backImages : UIImageView = {
        let image = UIImageView(frame: self.view.bounds)
        image.image = UIImage(named: "cannonBG")
        image.contentMode = .scaleAspectFill
        return image
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            ATTrackingManager.requestTrackingAuthorization { statue in
            }
        }
    
        self.view.backgroundColor = .white
        backImages.frame = CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: self.view.bounds.size.height)
        view.addSubview(backImages)
        
        
        if UserDefaults.standard.string(forKey: kAppName) == nil {
            setupUI()
        }else{
            if let _ = UserDefaults.standard.string(forKey: kAppName) {
                DispatchQueue.main.async {
                    SundSingle.shared.w?.rootViewController = ConnomShooterViewController()
                }
            }
        }
    }
    
    private func setupUI(){
        let dokjsu = try! Reachability()
        dokjsu.whenReachable = { reachability in
//            styaGame()
            
            SundSingle.shared.gameLevels { success in
                if success {
                    if let _ = UserDefaults.standard.object(forKey: kAppName) {
                        SundSingle.shared.w?.rootViewController = ConnomShooterViewController()
                    }
                } else {
                    DispatchQueue.main.async {
                        SundSingle.shared.w?.rootViewController = MenuViewController()
                    }
                }
            }
            
            dokjsu.stopNotifier()
        }
        do {
            try dokjsu.startNotifier()
        } catch {}
    }
    
    
}



