# PHS Connect Development - SwiftUi

> [!IMPORTANT]
> This is the development github for PHS Connect, you will not find the official code here. 
## Overview

> [!NOTE]
> PHS Connect is designed to provide a structured and interactive platform for students @ Prospect HS to discover, join, and manage clubs. 🎉 With features like personalized club recommendations, custom calendars, and streamlined communication tools, the app empowers students to engage more effectively in extracurricular activities.

---

## Features

### 1. **Club Management**

> [!NOTE]
>  **Manage clubs effortlessly** 🛠️

- **Leaders :**
  - Club leaders can manage members, make announcements, set meeting times, and fully edit their clubs.
- **Invite-Only Clubs:**
  - Users can request to join invite-only clubs, pending approval from leaders.

### 2. **User Profiles**

- Personalized profiles store:
  - Favorited clubs
  - Subject preferences
  - Clubs they are a part of
  - Pending club join requests

### 3. **Club Discovery**

- Users can:
  - Browse and search through clubs using name, info, or genre. 
  - View genres, meeting times, announcements, photos, information, and schoology codes to make informed decisions about joining.

### 4. **Custom Calendar View** (Will ship in 2025)

 📅 **Stay organized with our unique calendar feature!**

- A unique calendar feature displays meeting times for favorited clubs, independent of Apple’s system calendars.

### 5. **Announcements**

- Leaders can post announcements with timestamps to keep members informed.

### 6. **Google Login**

- Secure and convenient authentication using Google accounts.

### 7. **Firebase Integration**

- Data pulling powered by Firebase Realtime Database ensures full access to club information and editing of said information. 

---

## Technical Details

> [!IMPORTANT]
>  **Dive into the technical backbone** 🧑‍💻

### 1. **Custom UI Components**

- **Custom Calendar View :** (Will ship in 2025)
  - Built using SwiftUI to show meeting times on a calendar for enrolled clubs.
- **Lots more! :**

### 2. **Backend**

- **Firebase Realtime Database:**
  - Securely stores club and user data.
  - Ensures pulled updates for club information such as announcements, meeting times, schoology codes, etc. 
---

## Getting Started

### Prerequisites

- Xcode 14 or later
- Swift 5.7 or later
- Firebase SDK
- Google Sign-In configuration

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Immortal215/PHS-Connect-Development.git
   ```
2. Open the `.xcodeproj` file in Xcode.
3. Install dependencies via Swift Package Manager.
4. Configure Firebase by adding your `GoogleService-Info.plist` file to the project.
5. Make sure you do not share this file and add it to your .gitignore

### Running the App

1. Connect an iPad (optimized for Gen 10).
2. Build and run the app on your connected device or simulator.

## Contact

For questions or suggestions, please reach out to the development team.

