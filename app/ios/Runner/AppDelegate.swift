import Flutter
import UIKit
import PushKit
import flutter_callkit_incoming

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, PKPushRegistryDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    registerVoIP()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    setupProximityChannel(registry: engineBridge.pluginRegistry)
  }

  private func setupProximityChannel(registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "ProximitySensor") else { return }
    let channel = FlutterMethodChannel(name: "proximity_sensor", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "enable":
        UIDevice.current.isProximityMonitoringEnabled = true
      case "disable":
        UIDevice.current.isProximityMonitoringEnabled = false
      default: break
      }
      result(nil)
    }
  }

  private func registerVoIP() {
    let registry = PKPushRegistry(queue: .main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]
  }

  // MARK: - PKPushRegistryDelegate

  func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    print("VoIP push token: \(token)")
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(token)
  }

  func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
    let data = payload.dictionaryPayload
    let callerName = data["caller_name"] as? String ?? "Ismeretlen"
    let callerId = data["caller_id"] as? String ?? "unknown"
    let uuid = UUID().uuidString

    let callData = flutter_callkit_incoming.Data(
      id: uuid,
      nameCaller: callerName,
      handle: callerId,
      type: 0  // 0 = audio
    )
    callData.appName = "SIP App"
    callData.extra = ["caller_id": callerId] as NSDictionary

    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(callData, fromPushKit: true)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      let vc = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first(where: { $0.isKeyWindow })?.rootViewController as? FlutterViewController
      if let vc = vc {
        let channel = FlutterMethodChannel(name: "sip_reconnect", binaryMessenger: vc.binaryMessenger)
        channel.invokeMethod("reconnect", arguments: nil)
      }
    }

    completion()
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    print("VoIP push token invalidated")
  }
}
