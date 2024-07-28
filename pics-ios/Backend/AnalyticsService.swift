import AppCenterAnalytics
import Foundation

class AnalyticsService {
  static let shared = AnalyticsService()

  func deleted(url: URL, reason: String) {
    Analytics.trackEvent(
      "file_deleted", withProperties: ["url": url.absoluteString, "reason": reason])
  }
}
