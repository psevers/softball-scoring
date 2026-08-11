import Foundation
import Testing
@testable import SoftballScoring

struct SeasonTests {
    @Test func activatingSeasonDeactivatesEveryOtherSeason() {
        let spring = Season(name: "Spring", isActive: true)
        let summer = Season(name: "Summer", isActive: false)
        let fall = Season(name: "Fall", isActive: false)

        SeasonSelection.activate(summer, among: [spring, summer, fall])

        #expect(spring.isActive == false)
        #expect(summer.isActive == true)
        #expect(fall.isActive == false)
    }

    @Test func dateRangeUsesSingleYearWhenDatesShareYear() {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!
        let season = Season(name: "2026", startDate: start, endDate: end)

        #expect(season.dateRangeDescription == "2026")
    }
}
