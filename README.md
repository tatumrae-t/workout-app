# Workouts

A personal iPhone + Apple Watch app for running the 2-day plan, logging sets,
timing rest, and keeping your Strong history. It's not on the App Store: you
build it from Xcode onto your own devices.

## What it does

**Apple Watch**
- Pick Day A or Day B (the next one is marked "Up next").
- Each set is prefilled with the right weight and reps from last time. Turn the
  Digital Crown to change the weight, tap − / + for reps, then tap **Done**.
- A rest timer starts automatically and buzzes when it's time for the next set.
  Supersets alternate sets with no rest in between.
- Runs as an Apple Health strength workout, so heart rate and calories are
  tracked and it counts toward your rings.
- Swipe left for Finish / Undo / Skip, right for heart rate and time.
- When you finish, the workout is sent to your iPhone.

**iPhone**
- **Workout:** both days with targets and what you did last time. You can also
  run a workout from the phone (rest timer notifications included).
- **History:** every workout, including ones imported from Strong.
- **Lifts:** your best set per exercise over time, with a chart.
- **Settings:** import your Strong CSV export.

Progression follows the plan: when you hit the top of the rep range on every
set, the next session suggests +5 lb (or more reps first if you're at the 25 lb
dumbbells). On pull-ups it tells you when to drop to a lighter band.

## First-time setup (about 15 minutes)

You need the Mac with Xcode, your iPhone, and your Watch.

1. **Get the code.** In Terminal:
   ```sh
   git clone https://github.com/tatumrae-t/workout-app.git
   cd workout-app
   ./setup.sh
   ```
   This downloads a small tool called XcodeGen (once), creates
   `WorkoutApp.xcodeproj`, and opens it in Xcode.

2. **Sign in to Xcode.** Xcode › Settings › Accounts › **+** › Apple ID. A free
   Apple ID is fine.

3. **Pick your team.** In Xcode's left sidebar, click **WorkoutApp** (the blue
   icon at the top). For each of the two targets, **WorkoutApp** and
   **WorkoutWatch**, open **Signing & Capabilities** and set **Team** to your
   name (Personal Team).

4. **Get your iPhone ready.** Plug it into the Mac and tap **Trust**. Then on the
   iPhone: Settings › Privacy & Security › **Developer Mode** › on, and restart
   when asked.

5. **Run it on your iPhone.** At the top of Xcode, choose the **WorkoutApp**
   scheme and your iPhone, then press **Run** (▶). The first time, the iPhone
   will say the developer isn't trusted: go to Settings › General › VPN & Device
   Management, tap your Apple ID, and tap **Trust**. Then run again.

6. **Get your Watch ready.** Keep the iPhone plugged in and the Watch nearby and
   unlocked. On the Watch: Settings › Privacy & Security › **Developer Mode** ›
   on (it can take a minute to appear after step 5). The Watch restarts.

7. **Run it on your Watch.** Choose the **WorkoutWatch** scheme and your Watch,
   then press **Run**. The first launch can be slow while Xcode prepares the
   Watch. When the app asks for Health access, allow it.

8. **Import your history.** In Strong: Settings › Export Data, and save the CSV
   to Files. In this app: Settings › **Import Strong CSV**.

## Every 7 days (free Apple ID only)

Apps installed with a free Apple ID stop opening after 7 days. To renew, plug
in your iPhone and press **Run** in Xcode again for both schemes. Your workouts
are kept. A paid Apple Developer account ($99/yr) makes installs last a year.

## Updating the app

```sh
cd workout-app
git pull
./setup.sh
```
Then press **Run** for both schemes.

## How it's built

- `project.yml` describes the Xcode project; `./setup.sh` generates it.
- `Shared/`: plan, models, set-by-set workout logic, Strong CSV import.
  Used by both apps.
- `iOS/`: the iPhone app (SwiftUI).
- `Watch/`: the Watch app (SwiftUI, HealthKit workout session).
- The two apps talk over WatchConnectivity. The iPhone sends the plan and your
  latest weights; the Watch sends back finished workouts.
- Data is stored as JSON in each app's own storage. Nothing leaves your devices.
