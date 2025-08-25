import qs.components
import qs.services
import qs.config
import QtQuick
import QtQml
import Quickshell
import Quickshell.Io // for Process

Column {
  id: root

  property string app: "pomodoro-cli"
  property list<string> clickArgs: [root.app, "start"]
  property color colour: Colours.palette.m3tertiary
  property string timer: "00:00"
  property string state: "finished"
  property string tooltip: "finished"
  property string icon: "timer"

  property bool isWork: true
  property string workIcon: "work"
  property string breakIcon: "free_breakfast"
  property string pauseIcon: "pause_circle"
  property string finishedIcon: "timer"
  // property string icon: "timer"

  MaterialIcon {
    text: root.icon
    color: root.colour
    anchors.horizontalCenter: parent.horizontalCenter
  }

  StyledText {
    id: pomodoroStatus
    text: "🍅"
    anchors.horizontalCenter: parent.horizontalCenter
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

        if (root.state === "running" && isRightClick){
          root.clickArgs = [root.app, "stop"]
          root.icon = root.finishedIcon
        } 

        if (root.state === "running" && !isRightClick){
          root.clickArgs = [root.app, "pause"]
          root.icon = root.pauseIcon
        } 
        
        if (root.state === "paused") {
          root.clickArgs = [root.app, "start", "--resume"]
          root.icon = root.isWork ? root.workIcon : root.breakIcon
        }
        
        if (root.state === "finished" && isRightClick) {
          root.clickArgs = [root.app, "start", "-d", "5m"]
          root.icon = root.breakIcon
          root.isWork = false
        }
        
        if (root.state === "finished" && isMiddleClick) {
          root.clickArgs = [root.app, "start", "-d", "15m"]
          root.icon = root.breakIcon
          root.isWork = false
        }
        
        if(root.state === "finished" && !isRightClick && !isMiddleClick) {
          root.clickArgs = [root.app, "start", "-d", "25m"]
          root.icon = root.workIcon
          root.isWork = true
        }
        pomodoroClick.running = true
      }
    }
  }
}
