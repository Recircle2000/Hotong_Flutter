import UIKit
import Flutter

// Flutter의 UiKitView 요청을 실제 UIDatePicker 뷰로 연결해주는 팩토리다.
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

// 실제 iOS compact 날짜 선택기를 감싸는 PlatformView 구현체다.
final class IOSCompactDatePickerView: NSObject, FlutterPlatformView {
  private let container = UIView()
  private let picker = UIDatePicker()
  // picker 기본 문자열 대신 원하는 형식으로 보이게 할 라벨이다.
  private let titleLabel = UILabel()
  private let channel: FlutterMethodChannel

  init(
    frame: CGRect,
    viewId: Int64,
    args: [String: Any]?,
    messenger: FlutterBinaryMessenger
  ) {
    // viewId별 채널을 따로 만들어 여러 뷰가 떠도 이벤트가 섞이지 않게 한다.
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
    // 실제 터치와 팝업은 picker가 처리하고, 표시는 titleLabel이 맡는다.
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

    // 한국식 양력 기준으로 표시를 맞춘다.
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

    // Flutter는 millisecond epoch를 받으면 그대로 DateTime으로 복원할 수 있다.
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
