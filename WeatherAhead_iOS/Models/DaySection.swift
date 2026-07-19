import Foundation

/// One calendar day in the timeline, holding every place visited that day.
struct DaySection: Identifiable {
    let day: Date
    var entries: [PlaceDay]

    var id: Date { day }

    var isToday: Bool {
        Calendar.current.isDateInToday(day)
    }
}
