import SwiftUI

struct DateRangeControl: View {
    @Binding var options: ExportOptions
    @State private var showing = false
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Date range").font(.system(size: 12, weight: .medium))
            Button { showing = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "calendar").foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(options.dateFilter ? options.startDate.formatted(.dateTime.month(.abbreviated).day().year()) + " – " + options.endDate.formatted(.dateTime.month(.abbreviated).day().year()) : "All time")
                            .font(.system(size: 11, weight: .medium)).lineLimit(2)
                        Text(options.dateFilter ? "Change dates" : "Choose dates or a quick range").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.system(size: 10)).foregroundStyle(.secondary)
                }.padding(12).background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.primary.opacity(0.08)))
            }.buttonStyle(.plain).accessibilityLabel("Choose date range")
                .popover(isPresented: $showing, arrowEdge: .leading) {
                    RangeCalendar(options: $options, showing: $showing)
                }
        }
    }
}

struct RangeCalendar: View {
    @Binding var options: ExportOptions
    @Binding var showing: Bool
    @State private var start: Date
    @State private var end: Date
    @State private var month: Date
    @State private var choosingEnd = false
    @State private var allTime: Bool
    private let calendar = Calendar.current
    init(options: Binding<ExportOptions>, showing: Binding<Bool>) {
        _options = options; _showing = showing
        let value = options.wrappedValue
        _start = State(initialValue: value.dateFilter ? value.startDate : Date())
        _end = State(initialValue: value.dateFilter ? value.endDate : Date())
        _month = State(initialValue: Calendar.current.dateInterval(of: .month, for: value.dateFilter ? value.startDate : Date())!.start)
        _allTime = State(initialValue: !value.dateFilter)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Choose a date range").font(.system(size: 18, weight: .semibold))
                    Text(choosingEnd ? "Now choose the last day." : "Choose the first and last day, or use a preset.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { showing = false } label: { Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)) }.buttonStyle(.plain).help("Close calendar")
            }
            HStack(spacing: 8) {
                preset("All time", active: allTime) { allTime = true; choosingEnd = false }
                preset("Last 7 days") { quickDays(7) }
                preset("Last 30 days") { quickDays(30) }
                preset("This year") {
                    start = calendar.dateInterval(of: .year, for: Date())!.start; end = Date(); allTime = false; choosingEnd = false
                    month = calendar.dateInterval(of: .month, for: start)!.start
                }
            }
            HStack(spacing: 12) {
                dateCard("FROM", date: start, active: !allTime && !choosingEnd)
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                dateCard("TO", date: end, active: !allTime && choosingEnd)
            }
            HStack(alignment: .top, spacing: 25) {
                calendarMonth(month, first: true)
                calendarMonth(calendar.date(byAdding: .month, value: 1, to: month)!, first: false)
            }
            Divider()
            HStack {
                Text(allTime ? "All messages" : choosingEnd ? "Select an end date" : "\((calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0) + 1) days · Inclusive")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { showing = false }.buttonStyle(.plain)
                Button("Apply range") {
                    let ordered = CalendarRange.normalized(start, end)
                    var updated = options
                    updated.dateFilter = !allTime; updated.startDate = ordered.0; updated.endDate = ordered.1
                    options = updated; showing = false
                }.buttonStyle(.borderedProminent).controlSize(.large).disabled(choosingEnd)
            }
        }.padding(24).frame(width: 588)
    }
    private func preset(_ title: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.system(size: 11, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 8)
            .foregroundStyle(active ? Color.white : Color.primary)
            .background(active ? Color.blue : Color.primary.opacity(0.06), in: Capsule()) }.buttonStyle(.plain)
    }
    private func dateCard(_ title: String, date: Date, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
            Text(allTime ? "Any date" : date.formatted(.dateTime.month(.abbreviated).day().year())).font(.system(size: 13, weight: .medium))
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(active ? Color.blue.opacity(0.07) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? Color.blue : Color.clear))
    }
    private func quickDays(_ days: Int) {
        let range = CalendarRange.lastDays(days)
        start = range.0; end = range.1; allTime = false; choosingEnd = false
        month = calendar.dateInterval(of: .month, for: start)!.start
    }
    private func select(_ day: Date) {
        allTime = false
        if !choosingEnd { start = day; end = day; choosingEnd = true }
        else { let ordered = CalendarRange.normalized(start, day); start = ordered.0; end = ordered.1; choosingEnd = false }
    }
    private func calendarMonth(_ date: Date, first: Bool) -> some View {
        let monthStart = calendar.dateInterval(of: .month, for: date)!.start
        let offset = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
        let days = calendar.range(of: .day, in: .month, for: date)!.count
        return VStack(spacing: 12) {
            HStack(spacing: 4) {
                if first { Button { month = calendar.date(byAdding: .month, value: -1, to: month)! } label: { Image(systemName: "chevron.left") }.help("Previous month") }
                Spacer(minLength: 2)
                Menu {
                    ForEach(1...12, id: \.self) { value in
                        Button(calendar.monthSymbols[value - 1]) {
                            var components = calendar.dateComponents([.year, .month], from: date)
                            components.month = value
                            let chosen = calendar.date(from: components)!
                            month = first ? chosen : calendar.date(byAdding: .month, value: -1, to: chosen)!
                        }
                    }
                } label: { Text(date.formatted(.dateTime.month(.wide))) }.menuStyle(.borderlessButton).fixedSize()
                Menu {
                    ForEach(Array((2001...(calendar.component(.year, from: Date()) + 1)).reversed()), id: \.self) { year in
                        Button(String(year)) {
                            var components = calendar.dateComponents([.year, .month], from: date)
                            components.year = year
                            let chosen = calendar.date(from: components)!
                            month = first ? chosen : calendar.date(byAdding: .month, value: -1, to: chosen)!
                        }
                    }
                } label: { Text(date.formatted(.dateTime.year())) }.menuStyle(.borderlessButton).fixedSize()
                Spacer(minLength: 2)
                if !first { Button { month = calendar.date(byAdding: .month, value: 1, to: month)! } label: { Image(systemName: "chevron.right") }.help("Next month") }
            }.font(.system(size: 12, weight: .semibold)).buttonStyle(.plain).frame(height: 25)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 5) {
                ForEach(0..<7, id: \.self) { column in
                    Text(calendar.veryShortWeekdaySymbols[(calendar.firstWeekday - 1 + column) % 7]).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).frame(height: 20)
                }
                ForEach(0..<42, id: \.self) { slot in
                    let number = slot - offset + 1
                    if number > 0 && number <= days {
                        let day = calendar.date(byAdding: .day, value: number - 1, to: monthStart)!
                        let endpoint = !allTime && (calendar.isDate(day, inSameDayAs: start) || calendar.isDate(day, inSameDayAs: end))
                        let inRange = !allTime && day >= calendar.startOfDay(for: start) && day <= calendar.startOfDay(for: end)
                        Button { select(day) } label: {
                            Text(String(number)).font(.system(size: 12, weight: endpoint ? .semibold : .regular))
                                .frame(maxWidth: .infinity).frame(height: 30)
                                .foregroundStyle(endpoint ? Color.white : Color.primary)
                                .background(endpoint ? Color.blue : inRange ? Color.blue.opacity(0.13) : Color.clear, in: RoundedRectangle(cornerRadius: endpoint ? 8 : 0))
                                .overlay(alignment: .bottom) { if calendar.isDateInToday(day) { Circle().fill(endpoint ? Color.white : Color.blue).frame(width: 3, height: 3).offset(y: -3) } }
                        }.buttonStyle(.plain).accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                    } else { Color.clear.frame(height: 30) }
                }
            }
        }.frame(maxWidth: .infinity)
    }
}
