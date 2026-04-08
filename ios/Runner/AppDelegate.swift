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

      let routeFactory = IOSRoutePopupButtonFactory(messenger: controller.binaryMessenger)
      registrar(forPlugin: "IOSRoutePopupButton")?.register(
        routeFactory,
        withId: "hsro/ios_route_popup_button"
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

final class IOSRoutePopupButtonFactory: NSObject, FlutterPlatformViewFactory {
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
    IOSRoutePopupButtonView(
      frame: frame,
      viewId: viewId,
      args: args as? [String: Any],
      messenger: messenger
    )
  }
}

final class IOSRoutePopupButtonView: NSObject, FlutterPlatformView {
  private struct RouteOption {
    let id: Int
    let title: String
  }

  private let container = UIView()
  private let button = UIButton(type: .system)
  private let channel: FlutterMethodChannel
  private var routes: [RouteOption] = []
  private var selectedRouteId: Int?

  init(
    frame: CGRect,
    viewId: Int64,
    args: [String: Any]?,
    messenger: FlutterBinaryMessenger
  ) {
    channel = FlutterMethodChannel(
      name: "hsro/ios_route_popup_button_\(viewId)",
      binaryMessenger: messenger
    )

    super.init()

    configure(with: args)
    container.frame = frame
    container.backgroundColor = .clear

    button.translatesAutoresizingMaskIntoConstraints = false
    button.backgroundColor = .clear
    button.contentHorizontalAlignment = .center
    button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
    button.showsMenuAsPrimaryAction = true
    container.addSubview(button)

    NSLayoutConstraint.activate([
      button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      button.topAnchor.constraint(equalTo: container.topAnchor),
      button.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])

    rebuildMenu()
  }

  func view() -> UIView {
    container
  }

  private func configure(with args: [String: Any]?) {
    if let rawRoutes = args?["routes"] as? [Any] {
      routes = rawRoutes.compactMap { item in
        guard let dictionary = item as? [String: Any],
              let id = dictionary["id"] as? Int,
              let title = dictionary["title"] as? String else {
          return nil
        }

        return RouteOption(id: id, title: title)
      }
    }

    if let routeId = args?["selectedRouteId"] as? Int, routeId >= 0 {
      selectedRouteId = routeId
    }
  }

  private func rebuildMenu() {
    button.isEnabled = !routes.isEmpty
    button.menu = UIMenu(children: routes.map { route in
      UIAction(
        title: route.title,
        state: route.id == selectedRouteId ? .on : .off
      ) { [weak self] _ in
        self?.handleSelection(route.id)
      }
    })

    updateButtonAppearance()
  }

  private func handleSelection(_ routeId: Int) {
    selectedRouteId = routeId
    rebuildMenu()
    channel.invokeMethod("onChanged", arguments: routeId)
  }

  private func updateButtonAppearance() {
    let selectedRoute = routes.first { $0.id == selectedRouteId }
    let title = selectedRoute?.title ?? "노선을 선택하세요"
    let foregroundColor = selectedRoute == nil ? UIColor.secondaryLabel : UIColor.label
    let chevronImage = UIImage(systemName: "chevron.down")

    if #available(iOS 15.0, *) {
      var configuration = button.configuration ?? UIButton.Configuration.plain()
      configuration.title = title
      configuration.image = chevronImage
      configuration.imagePlacement = .trailing
      configuration.imagePadding = 6
      configuration.baseForegroundColor = foregroundColor
      configuration.contentInsets = .zero
      button.configuration = configuration
    } else {
      button.setTitle(title, for: .normal)
      button.setTitleColor(foregroundColor, for: .normal)
      button.setImage(chevronImage, for: .normal)
      button.tintColor = foregroundColor
      button.semanticContentAttribute = .forceRightToLeft
      button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: -6)
    }
  }
}
