import SwiftUI

enum MeetingClubResolver {
    static func club(for clubID: String, in clubs: [Club]) -> Club? {
        clubs.first(where: { $0.clubID == clubID })
    }
}

struct MeetingView: View {
    var meeting: Club.MeetingTime
    var scale: Double
    let hourHeight: CGFloat
    @State var meetingInfo: Bool
    var preview: Bool? = false
    var fixedDurationMinutes: Int? = nil
    @State var clubs: [Club]
    @AppStorage("darkMode") var darkMode = false

    var usesPhoneLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    var body: some View {
        let startTime = dateForMeeting(meeting)
        let endTime = endDateForMeeting(meeting)
        let startMinutes =
            Calendar.current.component(.hour, from: startTime) * 60
            + Calendar.current.component(.minute, from: startTime)
        let endMinutes =
            Calendar.current.component(.hour, from: endTime) * 60
            + Calendar.current.component(.minute, from: endTime)
        let durationMinutes = fixedDurationMinutes
            ?? max(endMinutes - startMinutes, 0)
        let showsInlinePreview = preview == true

        let startOffset = CGFloat(startMinutes) * hourHeight * scale / 60
        let duration = CGFloat(durationMinutes) * hourHeight * scale / 60

        if let club = MeetingClubResolver.club(for: meeting.clubID, in: clubs) {
            let clubColor = colorFromClub(club: club)
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                if usesPhoneLayout && !meetingInfo {
                    Rectangle()
                        .fill(Color(.systemBackground))
                        .clipShape(.rect(cornerRadius: 5))
                }

                if meetingInfo {
                    Rectangle()
                        .fill(clubColor.opacity(0.7))
                        .cornerRadius(5)
                } else {
                    Rectangle()
                        .fill(clubColor.opacity(0.2))
                        .cornerRadius(5)
                }

                HStack {
                    RoundedRectangle(cornerRadius: 25)
                        .frame(width: 4)
                        .foregroundStyle(clubColor.opacity(0.8))
                        .padding(4)
                        .padding(.trailing, -8)

                    VStack(alignment: .leading) {

                        if isTextVisible(
                            lineHeight: 15,
                            startOffset: 0,
                            duration: duration
                        ) {
                            HStack {
                                Text(
                                    String(meeting.title.prefix(1)).uppercased()
                                        + String(meeting.title.dropFirst())
                                )

                                if meeting.description != nil {
                                    Image(systemName: "text.alignleft")
                                        .font(.caption2)
                                }

                                if meeting.seriesID?.isEmpty == false {
                                    Image(systemName: "repeat")
                                        .font(.caption2)
                                        .accessibilityLabel("Repeating meeting")
                                }
                            }
                            .font(.footnote)
                            .lineLimit(1)
                            .foregroundStyle(
                                meetingInfo
                                    ? Color.white
                                    : (usesPhoneLayout
                                        ? Color.primary
                                        : clubColor)
                            )
                            .bold()
                        }

                        if isTextVisible(
                            lineHeight: 14,
                            startOffset: 15,
                            duration: duration
                        ) {
                            HStack {
                                Image(systemName: "clock")
                                    .padding(.trailing, -4)
                                Text(
                                    "\(startTime.formatted(date: .omitted, time: .shortened)) - \(endTime.formatted(date: .omitted, time: .shortened))"
                                )
                                .lineLimit(1)
                            }
                            .foregroundStyle(
                                meetingInfo
                                    ? Color.white
                                    : (usesPhoneLayout
                                        ? Color.secondary
                                        : clubColor.opacity(0.6))
                            )
                            .font(.caption2)
                        }

                        if isTextVisible(
                            lineHeight: 14,
                            startOffset: 29,
                            duration: duration
                        ) {
                            HStack {
                                Image(systemName: "person.circle")
                                    .padding(.trailing, -4)
                                Text(
                                    club.name
                                )
                                .lineLimit(1)
                            }
                            .foregroundStyle(
                                meetingInfo
                                    ? Color.white
                                    : (usesPhoneLayout
                                        ? Color.secondary
                                        : clubColor.opacity(0.6))
                            )
                            .font(.caption2)
                        }

                        if let location = meeting.location,
                            isTextVisible(
                                lineHeight: 14,
                                startOffset: 42,
                                duration: duration
                            )
                        {
                            HStack {
                                Image(systemName: "location.circle")
                                    .padding(.trailing, -4)
                                Text(
                                    .init(
                                        String(location.prefix(1)).uppercased()
                                            + String(location.dropFirst())
                                    )
                                )
                                .lineLimit(1)
                            }
                            .foregroundStyle(
                                meetingInfo
                                    ? Color.white
                                    : (usesPhoneLayout
                                        ? Color.secondary
                                        : clubColor.opacity(0.6))
                            )
                            .font(.caption2)
                        }

                        Spacer()
                    }
                    .frame(
                        maxWidth: max(0, geometry.size.width - 16),
                        maxHeight: duration,
                        alignment: .topLeading
                    )
                }
                .frame(
                    maxWidth: geometry.size.width,
                    maxHeight: duration,
                    alignment: .topLeading
                )
            }
            .saturation(darkMode ? 1.3 : 1.0)
            .brightness(darkMode ? 0.3 : 0.0)
            .frame(
                width: geometry.size.width,
                height: duration
            )
            .position(
                x: showsInlinePreview && usesPhoneLayout
                    ? geometry.size.width / 2
                    : geometry.size.width / -2,
                y: showsInlinePreview
                    ? (usesPhoneLayout ? duration / 2 : 0)
                    : startOffset + (duration / 2)
                        + (12 * (startOffset / geometry.size.height))
            )
        }
        }
    }

    func isTextVisible(
        lineHeight: CGFloat,
        startOffset: CGFloat,
        duration: CGFloat
    ) -> Bool {
        return lineHeight + startOffset <= duration
    }
}
