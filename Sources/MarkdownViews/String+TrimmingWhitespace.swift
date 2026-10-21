extension String {
    func trimmingWhitespace() -> String {
        var s = Substring(self)
        while let f = s.first, f == " " || f == "\t" { s = s.dropFirst() }
        while let l = s.last, l == " " || l == "\t" || l == "\r" { s = s.dropLast() }
        return String(s)
    }
}
