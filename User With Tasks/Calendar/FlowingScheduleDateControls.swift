import SwiftUI

struct FlowingScheduleDateControls: View {
    @Binding var selectedDate: Date
    var onSchoolScheduleTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            datePickerButton
            schoolScheduleButton
        }
        .fixedSize()
    }

    var datePickerButton: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue)

            DatePicker("", selection: $selectedDate, displayedComponents: [.date])
            .labelsHidden()
            .colorMultiply(.white)
            .foregroundStyle(.white)
            .foregroundColor(.white)
            .tint(.white)
            .overlay(alignment: .center) {
                Text(String(selectedDate.formatted(date: .abbreviated, time: .omitted)))
                .foregroundStyle(.white)
                .offset(x: 1)
            }
        }
        .fixedSize()
    }

    var schoolScheduleButton: some View {
        Button(action: onSchoolScheduleTap) {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(.white)
                .imageScale(.medium)
                .frame(width: 35, height: 35)
                .background(
                    Color.blue,
                    in: RoundedRectangle(cornerRadius: 8)
                )
        }
        .buttonStyle(.plain)
    }
}
