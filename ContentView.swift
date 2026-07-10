import SwiftUI
import WebKit

struct ContentView: View {
    @State private var isControlsVisible = true
    @State private var isVideoPlaying = false
    
    var body: some View {
        ZStack {
            FixedWebView(isControlsVisible: $isControlsVisible, isVideoPlaying: $isVideoPlaying)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        isControlsVisible.toggle()
                    }
                }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 10) {
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                isControlsVisible.toggle()
                            }
                        }) {
                            Image(systemName: isControlsVisible ? "eye.slash.fill" : "hand.tap.fill")
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 42, height: 34)
                                .background(.ultraThinMaterial)
                                .cornerRadius(10)
                                .foregroundColor(.white.opacity(0.8))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.2), lineWidth: 0.5))
                        }
                        .buttonStyle(ReflectiveGlassButtonStyle())
                        
                        if isControlsVisible {
                            DPadOverlay(isVideoPlaying: isVideoPlaying)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .bottom).combined(with: .opacity)
                                ))
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        // FORCE ANTI-DIMMING: Disables screen sleeping as long as this app view is open/visible
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        // Double-check fallback: Reinforces waking state whenever video playback status toggles
        .onChange(of: isVideoPlaying) { oldValue, newValue in
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }
}

class WebViewManager {
    static let shared: WKWebView = {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        return WKWebView(frame: .zero, configuration: config)
    }()
}

struct FixedWebView: UIViewRepresentable {
    @Binding var isControlsVisible: Bool
    @Binding var isVideoPlaying: Bool
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WebViewManager.shared
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "videoObserver")
        webView.configuration.userContentController.add(context.coordinator, name: "videoObserver")
        
        let scriptSource = """
        (function() {
            function attachVideoListeners(video) {
                if (video && !video.hasAttribute('data-tracked')) {
                    video.setAttribute('data-tracked', 'true');
                    video.addEventListener('play', function() {
                        window.webkit.messageHandlers.videoObserver.postMessage("playing");
                    });
                    video.addEventListener('pause', function() {
                        window.webkit.messageHandlers.videoObserver.postMessage("paused");
                    });
                    if (!video.paused) {
                        window.webkit.messageHandlers.videoObserver.postMessage("playing");
                    }
                }
            }
            var existingVideo = document.querySelector('video');
            if (existingVideo) attachVideoListeners(existingVideo);
            var observer = new MutationObserver(function(mutations) {
                var v = document.querySelector('video');
                if (v) attachVideoListeners(v);
            });
            observer.observe(document.body, { childList: true, subtree: true });
        })();
        """
        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView.configuration.userContentController.removeAllUserScripts()
        webView.configuration.userContentController.addUserScript(userScript)
        
        webView.customUserAgent = "Mozilla/5.0 (Web0S; Linux/SmartTV) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 SmartTV"
        
        if let url = URL(string: "https://www.youtube.com/tv") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: FixedWebView
        init(_ parent: FixedWebView) { self.parent = parent }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "videoObserver", let status = message.body as? String {
                DispatchQueue.main.async {
                    if status == "playing" {
                        self.parent.isVideoPlaying = true
                        UIApplication.shared.isIdleTimerDisabled = true
                        withAnimation(.smooth(duration: 0.4)) {
                            self.parent.isControlsVisible = false
                        }
                    } else {
                        self.parent.isVideoPlaying = false
                        UIApplication.shared.isIdleTimerDisabled = true // Keep true so D-pad browsing doesn't sleep either
                    }
                }
            }
        }
    }
    
    static func sendTVKey(code: Int, keyName: String) {
        let js = """
        (function() {
            var target = document.activeElement || document.body || document;
            var createEvent = function(type) {
                return new KeyboardEvent(type, { key: '\(keyName)', code: '\(keyName)', keyCode: \(code), which: \(code), bubbles: true, cancelable: true, view: window });
            };
            target.dispatchEvent(createEvent('keydown'));
            setTimeout(function() { target.dispatchEvent(createEvent('keyup')); }, 10);
        })();
        """
        WebViewManager.shared.evaluateJavaScript(js, completionHandler: nil)
    }
}

struct DPadOverlay: View {
    var isVideoPlaying: Bool
    let bWidth: CGFloat = 54
    let bHeight: CGFloat = 42
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Button(action: { FixedWebView.sendTVKey(code: 27, keyName: "Escape") }) {
                    Text("ESC").font(.system(size: 10, weight: .bold, design: .rounded)).frame(width: 65, height: 32).background(Color.red.opacity(0.25)).cornerRadius(8)
                }
                Button(action: { FixedWebView.sendTVKey(code: 32, keyName: " ") }) {
                    HStack(spacing: 4) {
                        Image(systemName: isVideoPlaying ? "pause.fill" : "play.fill").font(.system(size: 9))
                        Text(isVideoPlaying ? "PAUSE" : "PLAY").font(.system(size: 10, weight: .bold, design: .rounded))
                    }.frame(width: 95, height: 32).background(Color.white.opacity(0.12)).cornerRadius(8)
                }
            }
            VStack(spacing: 6) {
                Button(action: { FixedWebView.sendTVKey(code: 38, keyName: "ArrowUp") }) {
                    Image(systemName: "chevron.up").font(.system(size: 14, weight: .bold)).frame(width: bWidth, height: bHeight).background(Color.white.opacity(0.06)).cornerRadius(8)
                }
                HStack(spacing: 6) {
                    Button(action: { FixedWebView.sendTVKey(code: 37, keyName: "ArrowLeft") }) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold)).frame(width: bWidth, height: bHeight).background(Color.white.opacity(0.06)).cornerRadius(8)
                    }
                    Button(action: { FixedWebView.sendTVKey(code: 13, keyName: "Enter") }) {
                        Text("OK").font(.system(size: 12, weight: .black, design: .rounded)).frame(width: bWidth, height: bHeight).background(LinearGradient(colors: [.blue.opacity(0.5), .cyan.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)).cornerRadius(8)
                    }
                    Button(action: { FixedWebView.sendTVKey(code: 39, keyName: "ArrowRight") }) {
                        Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).frame(width: bWidth, height: bHeight).background(Color.white.opacity(0.06)).cornerRadius(8)
                    }
                }
                Button(action: { FixedWebView.sendTVKey(code: 40, keyName: "ArrowDown") }) {
                    Image(systemName: "chevron.down").font(.system(size: 14, weight: .bold)).frame(width: bWidth, height: bHeight).background(Color.white.opacity(0.06)).cornerRadius(8)
                }
            }
        }
        .buttonStyle(ReflectiveGlassButtonStyle())
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.1), .clear, .white.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.6))
    }
}

struct ReflectiveGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .background(configuration.isPressed ? Color.white.opacity(0.08) : Color.clear)
            .cornerRadius(8)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
