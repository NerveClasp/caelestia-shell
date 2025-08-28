import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQml
import Quickshell
import Quickshell.Io // for Process

StyledRect {
  id: root
  implicitWidth: Config.bar.sizes.innerWidth
  implicitHeight: layout.implicitHeight + (Config.bar.tray.background ? Appearance.padding.normal : Appearance.padding.small) * 2

  readonly property string workDuration: "25m"
  readonly property string shortBreakDuration: "5m"
  readonly property string longBreakDuration: "15m"
  readonly property int workPeriodsBeforeLongBreak: 4

  readonly property string workIcon: "work"
  readonly property string shortBreakIcon: "free_breakfast"
  readonly property string longBreakIcon: "weekend"
  readonly property string pausedIcon: "pause_circle"
  readonly property string finishedIcon: "timer"
  readonly property string playIcon: "play_circle"

  readonly property string workKind: "work"
  readonly property string shortBreakKind: "shortBreak"
  readonly property string longBreakKind: "longBreak"

  readonly property string app: "pomodoro-cli"

  property color colour: Colours.palette.m3tertiary
  property list<string> clickArgs: [root.app, "start"]

  property string timer: "00:00"
  property string timerMinutes: "00"
  property string timerSeconds: "00"
  property string state: "finished" // "running", "paused", "finished"
  property string tooltip: "finished"
  property string icon: root.finishedIcon // "work", "free_breakfast", "pause_circle", "timer"
  property string kind: "" // "work", "shortBreak", "longBreak"
  property int kindNth: 0 // how many periods of this kind have passed

  property bool isWorkPeriod: false
  property int workPeriods: 0

  Process {
    id: pomodoroJson
    command: ["pomodoro-cli", "status", "-f", "json"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        var values = text.replace("{", "").replace("}", "").split("\",\"").map(s => s.split("\":\"")[1])
        var timeAndMessage = values[0].split(" - ")
        var kindAndNth = timeAndMessage[1]

        // if custom message is set, text will be `"text":"00:00 - Time is up!"` when finished
        if (!!kindAndNth && kindAndNth.indexOf('#') > -1) {
          var kindParts = kindAndNth.split(" #")
          root.kind = kindParts[0]
          root.kindNth = parseInt(kindParts[1]) || 0
        }

        if (root.kind === root.workKind || root.kind === root.shortBreakKind) {
          root.isWorkPeriod = root.kind === root.workKind
          root.workPeriods = root.kindNth
        }

        root.timer = timeAndMessage[0].replace(":", "\n")
        var minutesAndSeconds = root.timer.split("\n")
        root.timerMinutes = minutesAndSeconds[0] || "00"
        root.timerSeconds = minutesAndSeconds[1] || "00"

        root.tooltip = values[1]
        root.state = values[2]
        // pomodoroStatus.text = root.timer

        // @TODO: improve state handling and icon changing logic
        if (root.state !== 'paused') {
          root.icon = root[`${root.kind}Icon`] || root.finishedIcon
        } else {
          root.icon = root.pausedIcon
        }
      }
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: pomodoroJson.running = true
  }

  Process {
    id: pomodoroClick
    command: root.clickArgs
    running: false
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    enabled: true
    acceptedButtons: Qt.AllButtons
    onClicked: (mouse) => {
      var isRightClick = mouse.button === Qt.RightButton;
      var isMiddleClick = mouse.button === Qt.MiddleButton;
      var isLeftClick = mouse.button === Qt.LeftButton;

      if (root.state === "running" && isRightClick) {
        root.clickArgs = [root.app, "stop"]
      }

      if (root.state === "running" && isMiddleClick) {
        root.clickArgs = [root.app, "start", "--add", "5m"] // Just 5 more minutes, mom!!!
      }

      if (root.state === "running" && isLeftClick) {
        root.clickArgs = [root.app, "pause"]
        root.icon = root.pausedIcon
      }

      if (root.state === "paused") {
        root.clickArgs = [root.app, "start", "--resume"]

        if (root.kind !== "longBreak") { // happens when we pause and restart the bar. In such case custom message is ` - Paused` %_%
          root.icon = root[`${root.kind}Icon`] || root.finishedIcon
        }
      }

      if (root.state === "finished" && isRightClick) {
        root.clickArgs = [root.app, "start", "-d", root.shortBreakDuration, "-m", `shortBreak #${root.workPeriods}`]
        root.icon = root.shortBreakIcon
        root.isWorkPeriod = false
      }

      if (root.state === "finished" && isMiddleClick) {
        root.clickArgs = [root.app, "start", "-d", root.longBreakDuration, "-m", `longBreak #0`] // @TODO: extract to a function
        root.icon = root.longBreakIcon
        root.isWorkPeriod = false
        root.workPeriods = 0 // force reset work periods on manual long break
      }

      if (root.state === "finished" && !isRightClick && !isMiddleClick) {
        if (root.isWorkPeriod) {
          root.workPeriods += 1

          if(root.workPeriods >= root.workPeriodsBeforeLongBreak) {
            root.clickArgs = [root.app, "start", "-d", root.longBreakDuration, "-m", `longBreak #0`] // @TODO: do we want to track long breaks taken? Do we want to track all kinds separately?
            root.workPeriods = 0
          }else{
            root.clickArgs = [root.app, "start", "-d", root.shortBreakDuration, "-m", `shortBreak #${root.workPeriods}`]
          }

          root.icon = root.shortBreakIcon
          root.isWorkPeriod = false
        } else {
          root.clickArgs = [root.app, "start", "-d", root.workDuration, "-m", `work #${root.workPeriods}`]
          root.icon = root.workIcon
          root.isWorkPeriod = true
        } 
      }
      pomodoroClick.running = true
    }
  }

  Column {
    id: layout

    anchors.centerIn: parent

    MaterialIcon {
      text: root.icon
      color: root.colour
      anchors.horizontalCenter: parent.horizontalCenter
      animate: true
    }

    // @TODO: can we animate text somehow? Maybe use three text elements and transition their positions?
    StyledText {
      id: pomodoroStatus
      text: root.timerMinutes
      anchors.horizontalCenter: parent.horizontalCenter
      horizontalAlignment: StyledText.AlignHCenter
      font.pointSize: Appearance.font.size.smaller
      font.family: Appearance.font.family.mono
      color: root.colour
      animate: false
    }

    StyledText {
      id: pomodoroStatusSeconds
      text: root.timerSeconds
      anchors.horizontalCenter: parent.horizontalCenter
      horizontalAlignment: StyledText.AlignHCenter
      font.pointSize: Appearance.font.size.smaller
      font.family: Appearance.font.family.mono
      color: root.colour
    }
  }
}
