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
    titleLabel.minimumScaleFactor = 0.8
    titleLabel.isUserInteractionEnabled = false
    container.addSubview(titleLabel)

    picker.translatesAutoresizingMaskIntoConstraints = false
    picker.backgroundColor = .clear
    picker.alpha = 0.02
    container.addSubview(picker)

    NSLayoutConstraint.activate([
      picker.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      picker.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      picker.topAnchor.constraint(equalTo: container.topAnchor),
      picker.bottomAnchor.constraint(equalTo: container.bottomAnchor),

      titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
      titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
      titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
    ])

    container.bringSubviewToFront(titleLabel)
    updateDisplayedDate()
  }

  func view() -> UIView {
    container
  }

  private func configurePicker(with args: [String: Any]?) {
    picker.datePickerMode = .date
    picker.locale = Locale(identifier: "ko_KR")

    if #available(iOS 14.0, *) {
      picker.preferredDatePickerStyle = .compact
    }

    if let timeZoneIdentifier = args?["timeZone"] as? String,
       let timeZone = TimeZone(identifier: timeZoneIdentifier) {
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
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "ko_KR")
    dateFormatter.timeZone = picker.timeZone
    dateFormatter.dateFormat = "yyyy년 MM월 dd일"

    let weekday = weekdayString(for: picker.date)
    titleLabel.text = "\(dateFormatter.string(from: picker.date))(\(weekday))"
  }

  private func weekdayString(for date: Date) -> String {
    switch Calendar(identifier: .gregorian).component(.weekday, from: date) {
    case 1:
      return "일"
    case 2:
      return "월"
    case 3:
      return "화"
    case 4:
      return "수"
    case 5:
      return "목"
    case 6:
      return "금"
    case 7:
      return "토"
    default:
      return ""
    }
  }
}
