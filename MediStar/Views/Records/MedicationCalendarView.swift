import Foundation
import SwiftUI
struct MedicationCalendarView: View {
    let selectedDate: Date
    let recordDates: Set<Date>
    let onSelect: (Date) -> Void

    @State private var displayedMonth: Date
    @GestureState private var dragOffset: CGFloat = 0

    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    init(
        selectedDate: Date,
        recordDates: Set<Date>,
        onSelect: @escaping (Date) -> Void
    ) {
        let normalizedDate = Calendar.current.startOfDay(for: selectedDate)
        self.selectedDate = normalizedDate
        self.recordDates = recordDates
        self.onSelect = onSelect
        _displayedMonth = State(initialValue: Self.startOfMonth(containing: normalizedDate))
    }

    private var today: Date {
        Calendar.current.startOfDay(for: .now)
    }

    private var currentMonth: Date {
        Self.startOfMonth(containing: today)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "chevron.up")
                    Text("Swipe up for earlier months · down to return")
                    Image(systemName: "chevron.down")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                monthView(displayedMonth)
                    .id(displayedMonth)
                    .offset(y: dragOffset * 0.18)
                    .opacity(1 - min(abs(dragOffset) / 500, 0.18))
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation.height
                            }
                            .onEnded { value in
                                guard abs(value.translation.height) > 55 else { return }
                                withAnimation(.easeInOut(duration: 0.24)) {
                                    if value.translation.height < 0 {
                                        moveDisplayedMonth(by: -1)
                                    } else {
                                        moveDisplayedMonth(by: 1)
                                    }
                                }
                            }
                    )
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.light)
        }
    }

    private func monthView(_ month: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.title3.bold())
                Spacer()
                if Calendar.current.isDate(month, equalTo: currentMonth, toGranularity: .month) {
                    Text("Current month")
                        .font(.caption2.bold())
                        .foregroundStyle(AppColors.accent)
                }
            }
            LazyVGrid(columns: columns, spacing: 9) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                ForEach(0..<leadingBlankCount(for: month), id: \.self) { _ in
                    Color.clear.frame(height: 42)
                }

                ForEach(1...numberOfDays(in: month), id: \.self) { day in
                    let date = date(in: month, day: day)
                    let isFuture = date > today
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)

                    Button {
                        guard !isFuture else { return }
                        onSelect(date)
                    } label: {
                        VStack(spacing: 3) {
                            Text("\(day)")
                                .font(.subheadline.bold())
                            Circle()
                                .fill(recordDates.contains(date) ? AppColors.accent : Color.clear)
                                .frame(width: 5, height: 5)
                        }
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .opacity(isFuture ? 0.24 : 1)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(
                            isSelected ? AppColors.accent : Color.clear,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isFuture)
                }
            }
        }
        .padding(16)
        .frame(minHeight: 390, alignment: .top)
        .background(AppColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: AppColors.cardShadow, radius: 14, y: 5)
    }

    private func leadingBlankCount(for month: Date) -> Int {
        Calendar.current.component(.weekday, from: month) - 1
    }

    private func numberOfDays(in month: Date) -> Int {
        guard let range = Calendar.current.range(of: .day, in: .month, for: month) else { return 30 }
        return range.count
    }

    private func date(in month: Date, day: Int) -> Date {
        Calendar.current.date(bySetting: .day, value: day, of: month) ?? month
    }

    private func moveDisplayedMonth(by value: Int) {
        guard let candidate = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth),
              candidate <= currentMonth else { return }
        displayedMonth = candidate
    }

    private static func startOfMonth(containing date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: components) ?? Calendar.current.startOfDay(for: date)
    }
}
