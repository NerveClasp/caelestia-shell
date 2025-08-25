import qs.components
import qs.services
import qs.config
import QtQuick
import QtQml
import Quickshell
import Quickshell.Io // for Process

Column {
  id: root

  readonly property string workDuration: "25m"
  readonly property string shortBreakDuration: "5m"
  readonly property string longBreakDuration: "15m"
  readonly property int workPeriodsBeforeLongBreak: 4

  readonly property string app: "pomodoro-cli"

  property color colour: Colours.palette.m3tertiary
  property list<string> clickArgs: [root.app, "start"]

  property string timer: "00:00"
  property string state: "finished" // "running", "paused", "finished"
  property string tooltip: "finished"
  property string icon: "timer" // "work", "free_breakfast", "pause_circle", "timer"

  property bool isWorkPeriod: true
  readonly property string workIcon: "work"
  readonly property string breakIcon: "free_breakfast"
  readonly property string pausedIcon: "pause_circle"
  readonly property string finishedIcon: "timer"

  property int workPeriods: 0

  MaterialIcon {
    text: root.icon
    color: root.colour
    anchors.horizontalCenter: parent.horizontalCenter
  }

  StyledText {
    id: pomodoroStatus
    text: "🍅"
    anchors.horizontalCenter: parent.horizontalCenter
    horizontalAlignment: StyledText.AlignHCenter
    font.pointSize: Appearance.font.size.smaller
    font.family: Appearance.font.family.mono
    color: root.colour

    Process {
      id: pomodoroJson
      command: ["pomodoro-cli", "status", "-f", "json"]
      running: true

      stdout: StdioCollector {
        onStreamFinished: {
          var values = text.replace("{", "").replace("}", "").split("\",\"").map(s => s.split("\":\"")[1])
          root.timer = values[0].replace(":", "\n")
          root.tooltip = values[1]
          root.state = values[2]
          pomodoroStatus.text = root.timer
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
          root.icon = root.finishedIcon
        }

        if (root.state === "running" && isMiddleClick) {
          root.clickArgs = [root.app, "start", "--add", "5m"] // Just 5 more minutes, mom!!!
          root.icon = root.finishedIcon
        }

        if (root.state === "running" && isLeftClick) {
          root.clickArgs = [root.app, "pause"]
          root.icon = root.pausedIcon
        }

        if (root.state === "paused") {
          root.clickArgs = [root.app, "start", "--resume"]
          root.icon = root.isWorkPeriod ? root.workIcon : root.breakIcon
        }

        if (root.state === "finished" && isRightClick) {
          root.clickArgs = [root.app, "start", "-d", root.shortBreakDuration]
          root.icon = root.breakIcon
          root.isWorkPeriod = false
        }

        if (root.state === "finished" && isMiddleClick) {
          root.clickArgs = [root.app, "start", "-d", root.longBreakDuration]
          root.icon = root.breakIcon
          root.isWorkPeriod = false
        }

        if (root.state === "finished" && !isRightClick && !isMiddleClick) {
          if (root.isWorkPeriod) {
            root.workPeriods += 1

            if(root.workPeriods >= root.workPeriodsBeforeLongBreak) {
              root.clickArgs = [root.app, "start", "-d", root.longBreakDuration]
              root.workPeriods = 0
            }else{
              root.clickArgs = [root.app, "start", "-d", root.shortBreakDuration]
            }

            root.icon = root.breakIcon
            root.isWorkPeriod = false
          } else {
            root.clickArgs = [root.app, "start", "-d", root.workDuration]
            root.icon = root.workIcon
            root.isWorkPeriod = true
          } 
        }
        pomodoroClick.running = true
      }
    }
  }
}
