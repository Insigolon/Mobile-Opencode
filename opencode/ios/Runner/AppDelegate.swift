import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

    private let methodChannelName = "dev.opencode/tailscale"
    private let statusChannelName = "dev.opencode/tailscale/status"

    private var tailscaleNode: Any?
    private var statusEventSink: FlutterEventSink?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        guard let controller = window?.rootViewController as? FlutterViewController
        else { return super.application(application, didFinishLaunchingWithOptions: launchOptions) }

        let methodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: controller.binaryMessenger
        )
        methodChannel.setMethodCallHandler { [weak self] call, result in
            guard let self else { return }
            switch call.method {
            case "start":
                let args     = call.arguments as? [String: Any] ?? [:]
                let hostname = args["hostname"] as? String ?? "opencode-mobile"
                let authKey  = args["authKey"]  as? String
                Task {
                    do {
                        let status = try await self.startNode(hostname: hostname, authKey: authKey)
                        result(status)
                    } catch {
                        result(FlutterError(code: "TS_START_FAILED",
                                            message: error.localizedDescription,
                                            details: nil))
                    }
                }

            case "stop":
                Task {
                    await self.stopNode()
                    result(nil)
                }

            case "getStatus":
                result(self.buildStatusMap())

            case "resolvePeer":
                let args     = call.arguments as? [String: Any] ?? [:]
                let hostname = args["hostname"] as? String ?? ""
                Task {
                    let ip = await self.resolvePeer(hostname: hostname)
                    result(ip)
                }

            case "listPeers":
                Task {
                    let peers = await self.listPeers()
                    result(peers)
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        FlutterEventChannel(
            name: statusChannelName,
            binaryMessenger: controller.binaryMessenger
        ).setStreamHandler(self)

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func startNode(
        hostname: String,
        authKey: String?
    ) async throws -> [String: Any?] {
        return buildStatusMap()
    }

    private func stopNode() async {
    }

    private func buildStatusMap() -> [String: Any?] {
        return ["state": "stopped"]
    }

    private func resolvePeer(hostname: String) async -> String? {
        return nil
    }

    private func listPeers() async -> [[String: Any?]] {
        return []
    }
}

extension AppDelegate: FlutterStreamHandler {
    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        statusEventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        statusEventSink = nil
        return nil
    }
}
