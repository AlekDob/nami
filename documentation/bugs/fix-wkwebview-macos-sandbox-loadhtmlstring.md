---
date: 2026-02-05
type: bug
status: workaround
severity: medium
tags: [swiftui, wkwebview, macos, sandbox]
---

# WKWebView macOS Sandbox - loadHTMLString() Fails

## Problema

Su macOS con App Sandbox abilitata, `WKWebView.loadHTMLString()` non renderizza nulla. La console mostra centinaia di errori sandbox.

## Sintomi

- Sheet si apre ma contenuto vuoto
- Console Xcode piena di errori tipo:
  ```
  XPC_ERROR_CONNECTION_INVALID
  Sandbox restriction
  rdar://problem/28724618
  Connection init failed at lookup with error 159
  ```

## Causa Root

macOS App Sandbox blocca le connessioni XPC necessarie a WKWebView per renderizzare contenuto caricato da stringa.

Questo e' un bug/limitazione nota di Apple (rdar://28724618).

## Tentativi Falliti

1. **Aggiungere entitlements** (`com.apple.security.network.client/server`) — Non risolve.
2. **WKWebViewConfiguration con javaScriptEnabled** — Non risolve.
3. **baseURL: URL(string: "about:blank")** — Non risolve.

## Soluzione Implementata (Workaround)

Su macOS, mostrare l'HTML come testo invece di renderizzarlo:

```swift
#if os(iOS)
struct WebPreview: UIViewRepresentable {
    let html: String
    func makeUIView(context: Context) -> WKWebView { WKWebView() }
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}
#else
struct WebPreview: View {
    let html: String
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(html)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding()
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
    }
}
#endif
```

## Alternative Non Implementate

1. **File temporaneo + Safari:** Salvare HTML in `/tmp/`, aprire con `NSWorkspace.shared.open()`
2. **Web server locale:** Servire file via localhost e caricare URL invece di stringa
3. **Disabilitare sandbox:** Solo per debug, non raccomandato

## Riferimenti

- rdar://28724618 (Apple bug report)
