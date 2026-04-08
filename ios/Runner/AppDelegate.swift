import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let factory = IOSCompactDatePickerFactory(messenger: controller.binaryMessenger)
      registrar(forPlugin: "IOSCompactDatePicker")?.register(
        factory,
        withId: "hsro/ios_compact_date_picker"
      )
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

final class IOSCompactDatePickerFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    IOSCompactDatePickerView(
      frame: frame,
      viewId: viewId,
      args: args as? [String: Any],
      messenger: messenger
    )
  }
}

final class IOSCompactDatePickerView: NSObject, FlutterPlatformView {
  private let container = UIView()
  private let picker = UIDatePicker()
  private let titleLabel = UILabel()
  private let channel: FlutterMethodChannel

  init(
    frame: CGRect,
    viewId: Int64,
    args: [String: Any]?,
    messenger: FlutterBinaryMessenger
  ) {
    channel = FlutterMethodChannel(
      name: "hsro/ios_compact_date_picker_\(viewId)",
      binaryMessenger: messenger
    )

    super.init()

    configurePicker(with: args)
    container.frame = frame
    container.backgroundColor = .clear

    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
    titleLabel.textColor = .label
    titleLabel.textAlignment = .center
    titleLabel.adjustsFontSizeToFitWidth = true
    titleLabel.minimumScaleFactor = 0.85
    titleLabel.isUserInteractionEnabled = false
    container.addSubview(titleLabel)

    picker.translatesAutoresizingMaskIntoConstraints = false
    picker.backgroundColor = .clear
    picker.alpha = 0.02
    container.addSubview(picker)

    NSLayoutConstraint.activate([
      picker.centerXAnchor.constraint(equalTo: container.centerXAnchor),
      picker.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      picker.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor),
      picker.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
      picker.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor),
      picker.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),

      titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
    ])

    container.bringSubviewToFront(titleLabel)
    updateDisplayedDate()
  }

  func view() -> UIView {
    container
  }

  private func configurePicker(with args: [String: Any]?) {
    picker.datePickerMode = .date
    let locale = Locale(identifier: "ko_KR@calendar=gregorian")
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = locale
    picker.locale = locale
    picker.calendar = calendar

    if #available(iOS 14.0, *) {
      picker.preferredDatePickerStyle = .compact
    }

    if let timeZoneIdentifier = args?["timeZone"] as? String,
       let timeZone = TimeZone(identifier: timeZoneIdentifier) {
      calendar.timeZone = timeZone
      picker.calendar = calendar
      picker.timeZone = timeZone
    }

    if let minimumDate = dateFromArgs(args?["minimumDate"]) {
      picker.minimumDate = minimumDate
    }

    if let maximumDate = dateFromArgs(args?["maximumDate"]) {
      picker.maximumDate = maximumDate
    }

    if let initialDate = dateFromArgs(args?["initialDate"]) {
      picker.date = initialDate
    }

    picker.addTarget(self, action: #selector(handleValueChanged), for: .valueChanged)
  }

  private func dateFromArgs(_ value: Any?) -> Date? {
    if let milliseconds = value as? Int64 {
      return Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000.0)
    }

    if let milliseconds = value as? Int {
      return Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000.0)
    }

    if let milliseconds = value as? NSNumber {
      return Date(timeIntervalSince1970: milliseconds.doubleValue / 1000.0)
    }

    return nil
  }

  @objc private func handleValueChanged() {
    updateDisplayedDate()
    let milliseconds = Int64(picker.date.timeIntervalSince1970 * 1000.0)
    channel.invokeMethod("onChanged", arguments: milliseconds)
  }

  private func updateDisplayedDate() {
    let formatter = DateFormatter()
    formatter.locale = picker.locale
    formatter.calendar = picker.calendar
    formatter.timeZone = picker.timeZone
    formatter.dateFormat = "yyyy년M월d일"
    titleLabel.text = formatter.string(from: picker.date)
  }
}
