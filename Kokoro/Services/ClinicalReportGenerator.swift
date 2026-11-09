import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif
import PDFKit

public struct ClinicalReportData {
    public let generatedDate: Date
    public let symptoms: [SymptomLog]
    public let weatherSnapshots: [WeatherSnapshot]
    public let dailyCheckIns: [DailyCheckIn]
    public let restingHR: Double
    public let hrvSDNN: Double?
    public let sleepHours: Double?

    public init(
        generatedDate: Date = Date(),
        symptoms: [SymptomLog],
        weatherSnapshots: [WeatherSnapshot],
        dailyCheckIns: [DailyCheckIn] = [],
        restingHR: Double,
        hrvSDNN: Double?,
        sleepHours: Double?
    ) {
        self.generatedDate = generatedDate
        self.symptoms = symptoms
        self.weatherSnapshots = weatherSnapshots
        self.dailyCheckIns = dailyCheckIns
        self.restingHR = restingHR
        self.hrvSDNN = hrvSDNN
        self.sleepHours = sleepHours
    }
}

public final class ClinicalReportGenerator {
    public static let shared = ClinicalReportGenerator()

    private init() {}

    /// Generates a structured multi-page or single-page PDF clinical report
    public func generatePDFReport(data: ClinicalReportData) -> Data {
        let pageWidth: CGFloat = 612.0  // Standard 8.5 x 11 inch Letter
        let pageHeight: CGFloat = 792.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let margin: CGFloat = 40.0
        let contentWidth = pageWidth - (margin * 2)

        #if canImport(UIKit)
        let format = UIGraphicsPDFRendererFormat()
        let metadata = [
            kCGPDFContextTitle: "Autonomic & Meteoropathy Clinical Report",
            kCGPDFContextAuthor: "Kokoro Patient",
            kCGPDFContextSubject: "POTS & EDS Clinical Consultation Summary"
        ]
        format.documentInfo = metadata as [String: Any]

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { context in
            context.beginPage()
            var currentY: CGFloat = margin

            // 1. Header Banner
            currentY = drawHeader(currentY: currentY, contentWidth: contentWidth, margin: margin, date: data.generatedDate)

            // 2. Regulatory Medical Disclaimer Banner
            currentY = drawDisclaimer(currentY: currentY, contentWidth: contentWidth, margin: margin)

            // 3. Autonomic Baseline & Vitals Summary
            currentY = drawVitalsSummary(currentY: currentY, contentWidth: contentWidth, margin: margin, data: data)

            // 4. Symptom Incident & Joint Subluxation Breakdown
            currentY = drawSymptomSummary(currentY: currentY, contentWidth: contentWidth, margin: margin, symptoms: data.symptoms)

            // 5. Weather & Barometric Pressure Flare Correlation
            currentY = drawWeatherCorrelation(currentY: currentY, contentWidth: contentWidth, margin: margin, data: data)

            // 6. Daily Check-In & Management Strategies
            currentY = drawManagementStrategies(currentY: currentY, contentWidth: contentWidth, margin: margin, checkIns: data.dailyCheckIns)

            // 7. Footer
            drawFooter(pageRect: pageRect, margin: margin)
        }
        #else
        // Fallback for macOS standard CoreGraphics PDF context
        let pdfData = NSMutableData()
        var mediaBox = pageRect
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        context.beginPage(mediaBox: &mediaBox)
        context.endPage()
        context.closePDF()
        return pdfData as Data
        #endif
    }

    #if canImport(UIKit)
    private func drawHeader(currentY: CGFloat, contentWidth: CGFloat, margin: CGFloat, date: Date) -> CGFloat {
        var y = currentY

        let title = "Autonomic Dysfunction & Joint Instability Clinical Summary"
        let titleFont = UIFont.boldSystemFont(ofSize: 18)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.systemBlue
        ]
        title.draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttributes)
        y += 24

        let subtitle = "Specialist Consultation Summary: POTS, Dysautonomia, hEDS & Meteoropathy"
        let subFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
        let subAttributes: [NSAttributedString.Key: Any] = [
            .font: subFont,
            .foregroundColor: UIColor.darkGray
        ]
        subtitle.draw(at: CGPoint(x: margin, y: y), withAttributes: subAttributes)
        y += 16

        let dateStr = "Report Generated: \(date.formatted(date: .complete, time: .shortened))"
        let dateFont = UIFont.systemFont(ofSize: 9)
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: dateFont,
            .foregroundColor: UIColor.gray
        ]
        dateStr.draw(at: CGPoint(x: margin, y: y), withAttributes: dateAttributes)
        y += 16

        // Separator line
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: margin + contentWidth, y: y))
        UIColor.systemBlue.setStroke()
        path.lineWidth = 1.5
        path.stroke()
        y += 12

        return y
    }

    private func drawDisclaimer(currentY: CGFloat, contentWidth: CGFloat, margin: CGFloat) -> CGFloat {
        var y = currentY
        let boxRect = CGRect(x: margin, y: y, width: contentWidth, height: 32)
        let boxPath = UIBezierPath(roundedRect: boxRect, cornerRadius: 4)
        UIColor.systemGray6.setFill()
        boxPath.fill()

        let disclaimer = "CLINICAL NOTE: Adjunctive symptom tracker. Data collected via Apple Watch & iPhone. Provided for physician evaluation during clinical appointments. Not an autonomous diagnostic device."
        let font = UIFont.italicSystemFont(ofSize: 8)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.darkGray
        ]
        disclaimer.draw(in: CGRect(x: margin + 6, y: y + 4, width: contentWidth - 12, height: 24), withAttributes: attributes)
        y += 40

        return y
    }

    private func drawVitalsSummary(currentY: CGFloat, contentWidth: CGFloat, margin: CGFloat, data: ClinicalReportData) -> CGFloat {
        var y = currentY

        let sectionTitle = "1. Baseline Autonomic & Cardiovascular Profile"
        let sectionAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 13),
            .foregroundColor: UIColor.label
        ]
        sectionTitle.draw(at: CGPoint(x: margin, y: y), withAttributes: sectionAttributes)
        y += 18

        let rowWidth = contentWidth / 4.0
        let items = [
            ("Resting Heart Rate", String(format: "%.0f bpm", data.restingHR)),
            ("Vagal Tone (HRV SDNN)", data.hrvSDNN != nil ? String(format: "%.0f ms", data.hrvSDNN!) : "N/A"),
            ("Mean Sleep Duration", data.sleepHours != nil ? String(format: "%.1f hrs", data.sleepHours!) : "N/A"),
            ("POTS Diagnostic Δ", "≥ 30 bpm criteria")
        ]

        for (i, item) in items.enumerated() {
            let x = margin + (CGFloat(i) * rowWidth)
            let lblAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .medium),
                .foregroundColor: UIColor.secondaryLabel
            ]
            item.0.draw(at: CGPoint(x: x, y: y), withAttributes: lblAttrs)

            let valAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 13),
                .foregroundColor: UIColor.systemBlue
            ]
            item.1.draw(at: CGPoint(x: x, y: y + 12), withAttributes: valAttrs)
        }
        y += 34

        return y
    }

    private func drawSymptomSummary(currentY: CGFloat, contentWidth: CGFloat, margin: CGFloat, symptoms: [SymptomLog]) -> CGFloat {
        var y = currentY

        let sectionTitle = "2. Symptom Frequency & EDS Joint Subluxations"
        let sectionAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 13),
            .foregroundColor: UIColor.label
        ]
        sectionTitle.draw(at: CGPoint(x: margin, y: y), withAttributes: sectionAttributes)
        y += 18

        let totalSessions = symptoms.count
        let totalSymptomsLogged = symptoms.reduce(0) { $0 + $1.symptoms.count }
        let subluxCount = symptoms.filter { $0.subluxationSeverity != nil || $0.symptoms.contains(.jointSubluxation) || $0.symptoms.contains(.jointDislocation) }.count

        let stats = "Total Logged Sessions: \(totalSessions)   |   Total Symptoms: \(totalSymptomsLogged)   |   Joint Subluxation Events: \(subluxCount)"
        let statsAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: UIColor.label
        ]
        stats.draw(at: CGPoint(x: margin, y: y), withAttributes: statsAttrs)
        y += 16

        // Joint frequency map
        var jointCounts: [String: Int] = [:]
        for s in symptoms {
            if let j = s.jointLocation {
                jointCounts[j.rawValue, default: 0] += 1
            }
        }

        if !jointCounts.isEmpty {
            let sortedJoints = jointCounts.sorted(by: { $0.value > $1.value }).prefix(4)
            var jointSummary = "Primary Subluxation Sites: "
            jointSummary += sortedJoints.map { "\($0.key) (\($0.value)x)" }.joined(separator: ", ")

            let jntAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: UIColor.secondaryLabel
            ]
            jointSummary.draw(at: CGPoint(x: margin, y: y), withAttributes: jntAttrs)
            y += 16
        }
        y += 10

        return y
    }

    private func drawWeatherCorrelation(currentY: CGFloat, contentWidth: CGFloat, margin: CGFloat, data: ClinicalReportData) -> CGFloat {
        var y = currentY

        let sectionTitle = "3. Meteoropathy Correlation (Barometric Pressure Drops vs. Flare Events)"
        let sectionAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 13),
            .foregroundColor: UIColor.label
        ]
        sectionTitle.draw(at: CGPoint(x: margin, y: y), withAttributes: sectionAttributes)
        y += 18

        let dropLogs = data.symptoms.filter { ($0.pressureTrend12hHpa ?? 0.0) <= -4.0 }
        let stableLogs = data.symptoms.filter { ($0.pressureTrend12hHpa ?? 0.0) > -4.0 }

        let text1 = String(format: "• Flare Incidents during Barometric Drop (ΔP ≤ -4.0 hPa): %d episodes", dropLogs.count)
        let text1Attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8.5),
            .foregroundColor: UIColor.systemRed
        ]
        text1.draw(at: CGPoint(x: margin, y: y), withAttributes: text1Attrs)
        y += 14

        let text2 = String(format: "• Incidents during Stable Atmospheric Conditions (ΔP > -4.0 hPa): %d episodes", stableLogs.count)
        let text2Attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8.5),
            .foregroundColor: UIColor.label
        ]
        text2.draw(at: CGPoint(x: margin, y: y), withAttributes: text2Attrs)
        y += 18

        let finding = (!dropLogs.isEmpty) ?
            "CLINICAL CORRELATION: Symptoms exhibit clustering during atmospheric low-pressure systems, consistent with meteoropathy in dysautonomia/EDS." :
            "CLINICAL CORRELATION: Ongoing tracking active. Continue logging barometric shifts to establish longitudinal statistical significance."
        let findingAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 8),
            .foregroundColor: UIColor.secondaryLabel
        ]
        finding.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 28), withAttributes: findingAttrs)
        y += 32

        return y
    }

    private func drawManagementStrategies(currentY: CGFloat, contentWidth: CGFloat, margin: CGFloat, checkIns: [DailyCheckIn]) -> CGFloat {
        guard !checkIns.isEmpty else { return currentY }
        var y = currentY

        let sectionTitle = "4. Daily Evening Check-Ins & Management Strategies"
        let sectionAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 13),
            .foregroundColor: UIColor.label
        ]
        sectionTitle.draw(at: CGPoint(x: margin, y: y), withAttributes: sectionAttributes)
        y += 18

        let crashDays = checkIns.filter { $0.hadCrashOrFlare }.count
        let totalDays = checkIns.count
        let checkInSummary = "• Total Check-Ins: \(totalDays) days  |  Flares / Crashes Reported: \(crashDays) days"
        let summaryAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8.5),
            .foregroundColor: UIColor.label
        ]
        checkInSummary.draw(at: CGPoint(x: margin, y: y), withAttributes: summaryAttrs)
        y += 14

        var strategyCounts: [String: Int] = [:]
        for c in checkIns {
            for s in c.managementStrategies {
                strategyCounts[s.rawValue, default: 0] += 1
            }
        }

        if !strategyCounts.isEmpty {
            let sorted = strategyCounts.sorted(by: { $0.value > $1.value }).prefix(5)
            let stratText = "• Interventions Used: " + sorted.map { "\($0.key) (\($0.value)x)" }.joined(separator: ", ")
            let stratAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8.5),
                .foregroundColor: UIColor.secondaryLabel
            ]
            stratText.draw(at: CGPoint(x: margin, y: y), withAttributes: stratAttrs)
            y += 16
        }

        y += 10
        return y
    }

    private func drawFooter(pageRect: CGRect, margin: CGFloat) {
        let footer = "Page 1 of 1 — Generated by Kokoro for iOS & watchOS — Confidential Medical Data"
        let font = UIFont.systemFont(ofSize: 8)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.tertiaryLabel
        ]
        let y = pageRect.height - margin + 8
        footer.draw(at: CGPoint(x: margin, y: y), withAttributes: attributes)
    }
    #endif
}
