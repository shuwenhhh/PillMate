import Foundation
import SwiftUI
struct MedicationCalendarView: View {
    let selectedMonth: Int
    let selectedDay: Int
    let recordDays: [Int: Set<Int>]
    let onSelect: (Int, Int) -> Void

    @State private var displayedMonth: Int
    @GestureState private var dragOffset: CGFloat = 0

    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    init(
        selectedMonth: Int,
        selectedDay: Int,
        recordDays: [Int: Set<Int>],
        onSelect: @escaping (Int, Int) -> Void
    ) {
        self.selectedMonth = selectedMonth
        self.selectedDay = selectedDay
        self.recordDays = recordDays
        self.onSelect = onSelect
        _displayedMonth = State(initialValue: selectedMonth)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "chevron.up")
                    Text("Swipe up for the previous month · down for the next")
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
                                        displayedMonth = max(1, displayedMonth - 1)
                                    } else {
                                        displayedMonth = min(12, displayedMonth + 1)
                                    }
                                }
                            }
                    )
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("2026 Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.light)
        }
    }

    private func monthView(_ month: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(Calendar.current.monthSymbols[month - 1]) 2026")
                    .font(.title3.bold())
                Spacer()
                if month == 8 {
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
                    Button {
                        onSelect(displayedMonth, day)
                    } label: {
                        VStack(spacing: 3) {
                            Text("\(day)")
                                .font(.subheadline.bold())
                            Circle()
                                .fill(recordDays[month]?.contains(day) == true ? AppColors.accent : Color.clear)
                                .frame(width: 5, height: 5)
                        }
                        .foregroundStyle(selectedMonth == month && selectedDay == day ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(
                            selectedMonth == month && selectedDay == day ? AppColors.accent : Color.clear,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(minHeight: 390, alignment: .top)
        .background(AppColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: AppColors.cardShadow, radius: 14, y: 5)
    }

    private func leadingBlankCount(for month: Int) -> Int {
        let components = DateComponents(year: 2026, month: month, day: 1)
        guard let date = Calendar.current.date(from: components) else { return 0 }
        return Calendar.current.component(.weekday, from: date) - 1
    }

    private func numberOfDays(in month: Int) -> Int {
        let components = DateComponents(year: 2026, month: month, day: 1)
        guard let date = Calendar.current.date(from: components),
              let range = Calendar.current.range(of: .day, in: .month, for: date) else { return 30 }
        return range.count
    }
}
