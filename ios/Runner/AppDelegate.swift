import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Flutter에서 요청하는 iOS 네이티브 PlatformView를 여기서 등록한다.
    if let controller = window?.rootViewController as? FlutterViewController {
      registerPlatformViews(messenger: controller.binaryMessenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func registerPlatformViews(messenger: FlutterBinaryMessenger) {
    // iOS compact 날짜 선택기
    registrar(forPlugin: "IOSCompactDatePicker")?.register(
      IOSCompactDatePickerFactory(messenger: messenger),
      withId: "hsro/ios_compact_date_picker"
    )

    // iOS 메뉴형 노선 선택 버튼
    registrar(forPlugin: "IOSRoutePopupButton")?.register(
      IOSRoutePopupButtonFactory(messenger: messenger),
      withId: "hsro/ios_route_popup_button"
    )
  }
}
