#if DEBUG
import AVFoundation

/// **A call, for a UI test** (ADR 0323). The test process can't reach the app's `NotificationCenter`,
/// and a simulator gives a test no way to ring or to start another app's audio, so the only way to see
/// a transport pause on screen is for the app to post the interruption itself when the test asks.
///
/// The test asks with a Darwin notification (`UITestHooks.interruptAudioNotification`), which crosses
/// the process boundary. The app answers with the `.began` interruption the system posts, so everything
/// downstream of it, the observer, the engines and the screens, is the real code. What it can't stand
/// in for is the system stopping the engine and deactivating the session: that half is the device's.
///
/// Debug builds only, and only under `-uiTesting` (`PocketApp.init`).
enum UITestInterruptionDrill {
    static func listen() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: AVAudioSession.interruptionNotification,
                        object: AVAudioSession.sharedInstance(),
                        userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
                }
            },
            UITestHooks.interruptAudioNotification as CFString, nil, .deliverImmediately)
    }
}
#endif
