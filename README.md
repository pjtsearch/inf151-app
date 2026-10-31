# inf151_app

GoalPunch tracks children's goals and check-ins using printed punch cards.

## Goal reminders

Reminders are optional and supported in the Android and iOS apps. Open the gear
button in the top app bar, then the **Reminders** section to enable **Goal reminders**
and choose a **Reminder time**. Changes save automatically. This single setting
applies to all goals. Notification permission is requested only when a parent
enables reminders. Turning reminders off retains the chosen time.

Daily goals check at the chosen local time each day, starting on the start date.
Weekly goals check on the start weekday, beginning one week later. Monthly goals
check on the corresponding month day, beginning one month later; short months use
their last day. A final partial week or month checks at the goal's end boundary.
Each check compares cumulative saved check-ins with the cumulative expected count,
capped at the goal's total. No alert is scheduled if those check-ins already cover
that date's target.

The app schedules local notifications rather than running a background worker.
Saving progress, changing the global settings, renaming a child, deleting goals,
and resuming the app rebuild the schedule and cancel stale requests. Completed
and ended goals have no future reminders. Parents need to scan and save check-ins
for notifications to reflect the physical cards.

The nearest 64 requests across all goals are queued to respect iOS's pending
notification limit; opening the app replenishes the queue and updates the device
time zone. Android uses inexact alarms, so the OS may delay delivery to conserve
battery. Scheduled background reminders are unavailable in the web app.

Device validation: allow/deny notification permission, choose a near-future daily
reminder, background the app, and confirm delivery. Repeat after recording enough
check-ins, disabling the reminder, deleting the goal, and rebooting Android to
confirm cancellation and schedule restoration. iOS delivery requires an iOS build
on macOS or a device.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
