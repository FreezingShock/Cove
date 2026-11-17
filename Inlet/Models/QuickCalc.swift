//
//  QuickCalc.swift
//  Inlet
//
//  Works out a typed sum for the search field: "2+2*3" shows "= 8". Pure
//  logic, no network. It is a small parser on purpose: NSExpression raises an
//  exception on some bad input, and a launcher must never crash on a keystroke.
//

import Foundation

enum QuickCalc {

    /// The value of `query` when the whole query is an arithmetic expression,
    /// otherwise nil. Needs a binary operator, so a plain number ("2024") or an
    /// app name never shows a result. A leading minus alone ("-5") does not count.
    static func evaluate(_ query: String) -> Double? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.dropFirst().contains(where: { operators.contains($0) }) else { return nil }

        var parser = Parser(text: trimmed)
        guard let value = parser.parseAll(), value.isFinite else { return nil }
        return value
    }

    /// The value as text. Whole numbers have no decimal point. Other numbers
    /// keep up to ten significant digits, so 1/3 reads as 0.3333333333.
    static func format(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int64(value))
        }
        return String(format: "%.10g", value)
    }

    /// Characters that count as an operator. × and ÷ are accepted so a pasted
    /// expression from a document still works.
    private static let operators: Set<Character> = ["+", "-", "*", "/", "×", "÷", "^"]

    /// Recursive-descent parser. Grammar, lowest precedence first:
    ///   sum     = product (("+" | "-") product)*
    ///   product = power (("*" | "/") power)*
    ///   power   = unary ("^" power)?          (right-associative)
    ///   unary   = "-" unary | primary
    ///   primary = number | "(" sum ")"
    /// Spaces are dropped before parsing. Anything left over is an error.
    private struct Parser {
        private let chars: [Character]
        private var index = 0

        init(text: String) {
            chars = Array(text.filter { !$0.isWhitespace })
        }

        /// Parses the whole input. Nil if it is malformed or has leftover text.
        mutating func parseAll() -> Double? {
            guard let value = parseSum(), index == chars.count else { return nil }
            return value
        }

        private mutating func parseSum() -> Double? {
            guard var value = parseProduct() else { return nil }
            while let op = peek(), op == "+" || op == "-" {
                index += 1
                guard let rhs = parseProduct() else { return nil }
                value = (op == "+") ? value + rhs : value - rhs
            }
            return value
        }

        private mutating func parseProduct() -> Double? {
            guard var value = parsePower() else { return nil }
            while let op = peek(), op == "*" || op == "×" || op == "/" || op == "÷" {
                index += 1
                guard let rhs = parsePower() else { return nil }
                if op == "*" || op == "×" {
                    value *= rhs
                } else {
                    guard rhs != 0 else { return nil } // no division by zero
                    value /= rhs
                }
            }
            return value
        }

        private mutating func parsePower() -> Double? {
            guard let base = parseUnary() else { return nil }
            guard peek() == "^" else { return base }
            index += 1
            guard let exponent = parsePower() else { return nil }
            return pow(base, exponent)
        }

        private mutating func parseUnary() -> Double? {
            guard peek() == "-" else { return parsePrimary() }
            index += 1
            guard let value = parseUnary() else { return nil }
            return -value
        }

        private mutating func parsePrimary() -> Double? {
            guard peek() == "(" else { return parseNumber() }
            index += 1
            guard let value = parseSum(), peek() == ")" else { return nil }
            index += 1
            return value
        }

        private mutating func parseNumber() -> Double? {
            let start = index
            while let c = peek(), c.isASCII, c.isNumber || c == "." {
                index += 1
            }
            guard index > start else { return nil }
            return Double(String(chars[start..<index]))
        }

        private func peek() -> Character? {
            index < chars.count ? chars[index] : nil
        }
    }
}
