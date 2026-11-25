import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// @brief Mission scheduler panel for the Plan view.
///
/// A schedule snapshots the current plan to a `.plan` file and stores it with
/// the date/time. When due, the Plan view loads the snapshot, uploads it and
/// starts the mission automatically.
Popup {
    id: panel

    property var scheduler: null
    property var planController: null
    property int tick: 0
    property int repeatIndex: 0
    property var weeklyDays: []
    property string errorText: ""
    property bool _busy: false
    property var _pendingEntry: null
    property int _uploadAttempts: 0

    signal startRequested(var entry)

    readonly property color _bg:       "#101114"
    readonly property color _surface:  "#0b0c0f"
    readonly property color _inputBg:  "#050506"
    readonly property color _border:   "#26282d"
    readonly property color _border2:  "#363a41"
    readonly property color _text:     "#f1f2f4"
    readonly property color _muted:    "#8b8f98"
    readonly property color _accent:   "#9a6bff"
    readonly property color _danger:   "#ef4444"

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    width: Math.min(860, parent.width - 80)
    height: Math.min(600, parent.height - 80)
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    padding: 0

    component YFieldLabel: Label {
        color: "#8b8f98"
        font.pixelSize: 10
        font.letterSpacing: 1.6
    }

    component YInput: TextField {
        color: "#f1f2f4"
        placeholderTextColor: "#676b73"
        font.pixelSize: 13
        selectByMouse: true
        leftPadding: 10
        rightPadding: 10
        background: Rectangle {
            radius: 8
            color: "#050506"
            border.width: 1
            border.color: parent.activeFocus ? "#9a6bff" : "#26282d"
        }
    }

    component YButton: Rectangle {
        id: btn
        property string label: "Button"
        property bool primary: false
        signal clicked()

        implicitHeight: 34
        implicitWidth: btnText.implicitWidth + 30
        radius: 8
        color: btn.primary ? "#8552f0" : "#1b1e23"
        border.width: btn.primary ? 0 : 1
        border.color: "#363a41"
        opacity: btnMouse.containsMouse ? 0.88 : 1.0

        Text {
            id: btnText
            anchors.centerIn: parent
            text: btn.label
            color: "#f1f2f4"
            font.pixelSize: 12
            font.bold: true
        }
        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    Timer {
        interval: 1000
        repeat: true
        running: panel.visible
        onTriggered: panel.tick++
    }

    // Uploads the current plan before the schedule is created, so the vehicle
    // already holds the mission and only needs a start command when it is due.
    Timer {
        id: _uploadPoll
        interval: 700
        repeat: true
        onTriggered: {
            panel._uploadAttempts++
            if (!panel._pendingEntry) {
                stop()
                panel._busy = false
                return
            }
            if (panel.planController.syncInProgress) {
                return
            }
            if (panel._uploadAttempts < 3) {
                return
            }
            if (panel.planController.dirtyForUpload && panel._uploadAttempts < 100) {
                return
            }
            stop()
            panel._busy = false
            if (panel.planController.dirtyForUpload) {
                panel.errorText = qsTr("Upload timed out. The plan was saved but not uploaded.")
                panel._pendingEntry = null
                return
            }
            const entry = panel._pendingEntry
            panel._pendingEntry = null
            panel.errorText = ""
            entry.uploaded = true
            entry.uploadedAt = new Date().toISOString()
            panel.scheduler.add(entry)
            panel.nameField.text = ""
        }
    }

    function _defaultDate() {
        return scheduler ? scheduler.todayString() : ""
    }

    function _defaultTime() {
        var d = new Date(Date.now() + 60 * 60 * 1000)
        d.setMinutes(0, 0, 0)
        var p = function(n) { return (n < 10 ? "0" : "") + n }
        return p(d.getHours()) + ":" + p(d.getMinutes())
    }

    function openPanel() {
        nameField.text = ""
        dateField.text = _defaultDate()
        timeField.text = _defaultTime()
        endField.text = ""
        customField.text = ""
        repeatIndex = 0
        weeklyDays = []
        errorText = ""
        tick++
        open()
        nameField.forceActiveFocus()
    }

    function _toggleDay(index) {
        var next = []
        for (var i = 0; i < weeklyDays.length; i++) {
            if (weeklyDays[i] !== index) next.push(weeklyDays[i])
        }
        if (weeklyDays.indexOf(index) < 0) next.push(index)
        next.sort()
        weeklyDays = next
    }

    function _trySchedule() {
        errorText = ""
        if (!scheduler) {
            errorText = qsTr("Scheduler is not available.")
            return
        }
        if (!planController) {
            errorText = qsTr("Plan controller is not available.")
            return
        }
        var name = nameField.text.trim()
        var date = dateField.text.trim()
        var time = timeField.text.trim()
        var start = new Date(date + "T" + time)
        if (isNaN(start.getTime())) {
            errorText = qsTr("Enter a valid date (YYYY-MM-DD) and time (HH:MM).")
            return
        }
        if (start.getTime() <= Date.now()) {
            errorText = qsTr("Choose a future date and time.")
            return
        }
        var repeat = ["once", "daily", "weekly", "custom"][repeatIndex]
        if (repeat === "weekly" && weeklyDays.length === 0) {
            errorText = qsTr("Select at least one weekday.")
            return
        }
        var dates = []
        if (repeat === "custom") {
            var parts = customField.text.split(",")
            for (var i = 0; i < parts.length; i++) {
                var v = parts[i].trim()
                if (v) dates.push(v)
            }
            if (!dates.length) {
                errorText = qsTr("Add at least one custom date (YYYY-MM-DD).")
                return
            }
        }
        var end = endField.text.trim()
        if (end && end < date) {
            errorText = qsTr("End date cannot be before the start date.")
            return
        }

        const vehicle = QGroundControl.multiVehicleManager.activeVehicle
        if (!vehicle || vehicle.isOfflineEditingVehicle) {
            errorText = qsTr("Connect a flight controller before scheduling a mission.")
            return
        }

        var id = "sm_" + Date.now() + "_" + Math.floor(Math.random() * 10000)
        var planFile = scheduler.newSchedulePath(id)
        if (!planController.saveToFile(planFile)) {
            errorText = qsTr("Unable to save the plan snapshot for this schedule.")
            return
        }

        _pendingEntry = {
            id: id,
            name: name || qsTr("Untitled Mission"),
            planFile: planFile,
            startDateTime: date + "T" + time + ":00",
            repeat: repeat,
            weeklyDays: repeat === "weekly" ? weeklyDays : undefined,
            customDates: repeat === "custom" ? dates : undefined,
            endDateTime: (repeat === "daily" || repeat === "weekly") && end ? end + "T23:59:59" : null,
            status: "scheduled",
            enabled: true,
            uploaded: false,
            vehicleId: vehicle.id,
            createdAt: new Date().toISOString()
        }
        _uploadAttempts = 0
        _busy = true
        errorText = ""
        planController.sendToVehicle()
        _uploadPoll.restart()
    }

    background: Rectangle {
        radius: 16
        color: panel._bg
        border.width: 1
        border.color: panel._border2
    }

    contentItem: ColumnLayout {
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 14
                Label {
                    text: qsTr("Mission Scheduler")
                    color: panel._text
                    font.pixelSize: 20
                    font.bold: true
                }
                Label {
                    Layout.leftMargin: 8
                    text: qsTr("SAVED PLAN · LOCAL TIME")
                    color: panel._accent
                    font.pixelSize: 10
                    font.letterSpacing: 1.6
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 30; height: 30; radius: 8
                    color: closeMouse.containsMouse ? panel._border2 : "transparent"
                    Text { anchors.centerIn: parent; text: "✕"; color: panel._muted; font.pixelSize: 15 }
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.close()
                    }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: panel._border }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 18
            spacing: 20

            // Create form
            ColumnLayout {
                Layout.preferredWidth: 340
                Layout.fillHeight: true
                spacing: 12

                YFieldLabel { text: qsTr("MISSION NAME") }
                YInput {
                    id: nameField
                    Layout.fillWidth: true
                    placeholderText: qsTr("e.g. Survey Area")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        YFieldLabel { text: qsTr("DATE") }
                        YInput { id: dateField; Layout.fillWidth: true; placeholderText: "YYYY-MM-DD" }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        YFieldLabel { text: qsTr("TIME") }
                        YInput { id: timeField; Layout.fillWidth: true; placeholderText: "HH:MM" }
                    }
                }

                YFieldLabel { text: qsTr("REPEAT") }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: [qsTr("Once"), qsTr("Daily"), qsTr("Weekly"), qsTr("Custom")]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 8
                            color: panel.repeatIndex === index ? panel._accent : panel._surface
                            border.width: 1
                            border.color: panel.repeatIndex === index ? panel._accent : panel._border
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: panel._text
                                font.pixelSize: 11
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: panel.repeatIndex = index
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: panel.repeatIndex === 2
                    spacing: 5
                    YFieldLabel { text: qsTr("WEEKDAYS") }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        Repeater {
                            model: ["S", "M", "T", "W", "T", "F", "S"]
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                radius: 7
                                property bool selected: panel.weeklyDays.indexOf(index) >= 0
                                color: selected ? panel._accent : panel._surface
                                border.width: 1
                                border.color: selected ? panel._accent : panel._border
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: panel._text
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: panel._toggleDay(index)
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: panel.repeatIndex === 3
                    spacing: 5
                    YFieldLabel { text: qsTr("DATES (COMMA SEPARATED)") }
                    YInput { id: customField; Layout.fillWidth: true; placeholderText: "2026-12-01, 2026-12-08" }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: panel.repeatIndex === 1 || panel.repeatIndex === 2
                    spacing: 5
                    YFieldLabel { text: qsTr("END DATE (OPTIONAL)") }
                    YInput { id: endField; Layout.fillWidth: true; placeholderText: "YYYY-MM-DD" }
                }

                Item { Layout.fillHeight: true }

                Label {
                    Layout.fillWidth: true
                    visible: panel.errorText !== "" || panel._busy
                    text: panel._busy ? qsTr("Uploading mission to the vehicle...") : panel.errorText
                    color: panel._busy ? "#f59e0b" : panel._danger
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }

                YButton {
                    Layout.fillWidth: true
                    primary: true
                    implicitHeight: 40
                    label: qsTr("Schedule Mission")
                    onClicked: { if (!panel._busy) panel._trySchedule() }
                }

                Label {
                    Layout.fillWidth: true
                    text: qsTr("Saves the current plan and launches it automatically at the scheduled time.")
                    color: panel._muted
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }
            }

            // Schedule list
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    YFieldLabel { text: qsTr("SCHEDULED MISSIONS") }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: panel.scheduler ? panel.scheduler.schedules.length : 0
                        color: panel._accent
                        font.pixelSize: 11
                        font.bold: true
                    }
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: panel.scheduler ? panel.scheduler.schedules : []

                    delegate: Rectangle {
                        width: list.width
                        height: 68
                        radius: 10
                        color: panel._surface
                        border.width: 1
                        border.color: panel._border

                        property bool enabledRow: modelData.enabled !== false
                        property string statusText: {
                            panel.tick
                            return modelData.status || "scheduled"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            spacing: 10

                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: !enabledRow ? panel._muted
                                     : (statusText === "waiting" ? "#f59e0b"
                                     : (statusText === "completed" ? "#34d399"
                                     : (statusText === "failed" ? panel._danger : panel._accent)))
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Label {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: panel._text
                                    font.pixelSize: 13
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: {
                                        panel.tick
                                        var s = panel.scheduler
                                        var base = (s ? s.repeatText(modelData) : "") + " · " +
                                                   (s ? s.countdownText(modelData) : "") + " · " + statusText
                                        if (statusText === "failed" && modelData.lastError)
                                            base += " · " + modelData.lastError
                                        return base
                                    }
                                    color: panel._muted
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }

                            YButton {
                                label: enabledRow ? qsTr("Pause") : qsTr("Resume")
                                onClicked: panel.scheduler.setEnabled(modelData.id, !enabledRow)
                            }
                            YButton {
                                primary: true
                                label: qsTr("Start")
                                onClicked: {
                                    panel.startRequested(modelData)
                                    panel.close()
                                }
                            }
                            Rectangle {
                                width: 30; height: 30; radius: 8
                                color: delMouse.containsMouse ? "#2a1216" : "transparent"
                                Text { anchors.centerIn: parent; text: "🗑"; font.pixelSize: 13; color: panel._muted }
                                MouseArea {
                                    id: delMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: panel.scheduler.remove(modelData.id)
                                }
                            }
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        visible: list.count === 0
                        text: qsTr("No missions scheduled yet.")
                        color: panel._muted
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
