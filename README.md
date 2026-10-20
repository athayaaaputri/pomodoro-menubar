# Pomodoro for the macOS menu bar

A small, native Pomodoro timer that lives in your Mac's menu bar, next to Wi-Fi and battery. Click the timer icon to open it, pick a rhythm, and press **Start**. When a session ends, a pop-up and a chime tell you it's time for a break, and when the break ends, that it's time to focus again.

## What is the Pomodoro Technique?

The Pomodoro Technique is a way to manage your time. You work in focused blocks, take short breaks in between, and after a few blocks you take a longer break. Short, timed sessions make it easier to start a task and stay on it, and the regular breaks help you avoid burning out.

## Two rhythms

| Mode | Focus | Short break | Long break | Long break comes after |
|------|-------|-------------|------------|------------------------|
| **25 / 5**  | 25 min | 5 min  | 15 min | every 4 focus sessions |
| **50 / 10** | 50 min | 10 min | 15 min | every 2 focus sessions |

A full 25 / 5 cycle looks like this:

```
Focus → Break → Focus → Break → Focus → Break → Focus → Long break → (repeat)
```

And a 50 / 10 cycle:

```
Focus → Break → Focus → Long break → (repeat)
```

## Features

- **Menu bar icon:** a timer icon sits in the menu bar. While the timer runs, the countdown appears next to it (for example `⏱ 24:13`). During breaks the icon becomes a coffee cup.
- **Panel:** click the icon to see a progress ring, the current phase, and dots showing how far you are through the cycle.
- **Colours for each phase:** red for focus, green for a short break, blue for a long break.
- **Pop-up when time's up:** a small notice slides in at the top right of the screen with a chime. You don't need to turn on notification permissions for it.
- **Auto-start:** optionally starts the next phase on its own, so you can keep going without clicking.
- **Controls:** Start / Pause (or press Space), Reset, and Skip to jump to the next phase.
- **Daily counter:** counts the focus sessions you finish each day.
- **Open at login:** optionally starts the app when you log in.
- **Remembers your settings:** your mode and options are kept between launches.
- **Not in the Dock:** the app only shows in the menu bar.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode Command Line Tools, which provide the Swift compiler. Install them with:

  ```bash
  xcode-select --install
  ```

## Build and install

```bash
git clone https://github.com/athayaaaputri/pomodoro-menubar.git
cd pomodoro-menubar
./build.sh
```

`build.sh` compiles the app, signs it so it can run on your Mac, copies it to `~/Applications/Pomodoro.app`, and opens it. Run it again any time you change the code.

After that, you can open the app from Spotlight by typing "Pomodoro".

## Uninstall

Click the menu bar icon, choose **Quit Pomodoro**, then delete `~/Applications/Pomodoro.app`.

## Project layout

```
Pomodoro.swift   # the whole app (SwiftUI): timer logic, menu bar panel, pop-up
build.sh         # compiles, bundles, signs and installs the app
```

## Customising

The durations are set in the `Mode` enum near the top of `Pomodoro.swift`:

```swift
var focus: Int  { self == .classic ? 25 : 50 }
var short: Int  { self == .classic ? 5 : 10 }
var long: Int   { 15 }
var every: Int  { self == .classic ? 4 : 2 }
```

Change the numbers and run `./build.sh` again.
