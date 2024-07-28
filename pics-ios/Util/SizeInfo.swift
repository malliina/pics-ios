import Foundation

struct SizeInfo {
  let itemsPerRow: Int
  let sizePerItem: CGSize

  static func forItem(minWidthPerItem: Double, totalWidth: Double) -> SizeInfo {
    let spaceBetweenItems = 10.0
    // for n items in a row, we have n-1 spaces between them, therefore
    // nx + (n-1)s = w
    // where n = items per row, x = width per item, s = space between items, w = width of frame
    // solves for n with a given minimum x, then solves for x given n
    let itemsPerRow = floor(
      (totalWidth + spaceBetweenItems) / (minWidthPerItem + spaceBetweenItems))
    let widthPerItem = (totalWidth - (itemsPerRow - 1.0) * spaceBetweenItems) / itemsPerRow
    // log.info("Got width \(widthPerItem) for \(indexPath.row) with total width \(view.frame.width)")
    // aspect is 4/3 for all thumbnails
    return SizeInfo(
      itemsPerRow: Int(itemsPerRow),
      sizePerItem: CGSize(width: widthPerItem, height: widthPerItem * 3.0 / 4.0))
  }
}
