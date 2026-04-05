import Foundation

extension String {
    /// Strips HTML tags from the string, including inner content of script/style blocks
    /// and HTML comments. HTML entities (e.g. &amp;) are left as-is.
    var removingHTMLTags: String {
        var result = self
        // Strip content inside script and style blocks (tags + inner text)
        result = result.replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>",
                                             with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>",
                                             with: "", options: .regularExpression)
        // Strip HTML comments
        result = result.replacingOccurrences(of: "<!--[\\s\\S]*?-->",
                                             with: "", options: .regularExpression)
        // Strip remaining tags
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return result
    }
}
