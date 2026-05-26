import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "dockerUtils.js" as DockerUtils
import "Components"
import qs.Commons
import qs.Services.System
import qs.Widgets
import qs.Modules.MainScreen

Item {
    id: root

    property var pluginApi: null
    // readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true
    property real contentPreferredWidth: 850 * Style.uiScaleRatio
    property real contentPreferredHeight: 600 * Style.uiScaleRatio
    property int currentTabIndex: 0
    property var _cachedContainers: []
    property var _pendingCallback: null

    function refreshAll() {
        containerProcess.running = true;
        volumeProcess.running = true;
        networkProcess.running = true;
    }

    function runCommand(cmdArgs, callback) {
        if (commandRunner.running) {
            console.warn("Command runner busy, ignoring:", cmdArgs);
            return;
        }
        root._pendingCallback = callback;
        commandRunner.command = cmdArgs;
        commandRunner.running = true;
    }

    function startContainer(id) {
        runCommand(["docker", "start", id], refreshAll);
    }

    function stopContainer(id) {
        runCommand(["docker", "stop", id], refreshAll);
    }

    function restartContainer(id) {
        runCommand(["docker", "restart", id], refreshAll);
    }

    function removeContainer(id) {
        runCommand(["docker", "rm", id], refreshAll);
    }

    function removeImage(id) {
        runCommand(["docker", "rmi", id], refreshAll);
    }

    function removeVolume(name) {
        runCommand(["docker", "volume", "rm", name], refreshAll);
    }

    function removeNetwork(id) {
        runCommand(["docker", "network", "rm", id], refreshAll);
    }

    function attemptRunImage(repo, tag) {
        // Reset dialog and start inspect to get default port
        runImageDialog.resetFields(repo, tag, "8080");

        inspectProcess.targetImage = repo + ":" + tag;
        inspectProcess.running = true;
    }

    function finalizeRunImage(image, port, network, name, envVars) {
        var cmd = ["docker", "run", "-d"];
        if (name && name.trim() !== "") {
            cmd.push("--name");
            cmd.push(name.trim());
        }
        if (envVars && envVars.length > 0) {
            envVars.forEach(function (e) {
                cmd.push("-e");
                cmd.push(e);
            });
        }
        if (port && port.trim() !== "") {
            cmd.push("-p");
            cmd.push(port + ":" + port);
        }
        if (network && network.trim() !== "" && network !== "bridge") {
            cmd.push("--network");
            cmd.push(network);
        }
        cmd.push(image);
        runCommand(cmd, refreshAll);
    }

    anchors.fill: parent
    Component.onCompleted: refreshAll()

    ListModel {
        id: containersModel
    }
    ListModel {
        id: imagesModel
    }
    ListModel {
        id: volumesModel
    }
    ListModel {
        id: networksModel
    }

    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        NBox {
            id: headerBox
            Layout.fillWidth: true
            implicitHeight: header.implicitHeight + Style.marginM + Style.marginM

            ColumnLayout {
                id: header
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginM

                RowLayout {
                    id: headerRow
                    NIcon {
                        icon: "brand-docker"
                        pointSize: Style.fontSizeXXL
                        color: Color.mPrimary
                    }

                    NText {
                        text: "Mini Docker"
                        pointSize: Style.fontSizeL
                        font.weight: Style.fontWeightBold
                        color: Color.mOnSurface
                        Layout.fillWidth: true
                    }

                    NIconButton {
                        icon: "refresh"
                        tooltipText: "Refresh"
                        onClicked: refreshAll()
                        baseSize: Style.baseWidgetSize * 0.8
                    }

                    NIconButton {
                        icon: "close"
                        tooltipText: I18n.tr("common.close")
                        baseSize: Style.baseWidgetSize * 0.8
                        onClicked: root.close()
                    }
                }

                NTabBar {
                    id: tabsBox
                    Layout.fillWidth: true
                    currentIndex: 0 // panelContent.currentRange
                    tabHeight: Style.toOdd(Style.baseWidgetSize * 0.8)
                    spacing: Style.marginXS
                    distributeEvenly: true

                    NTabButton {
                        tabIndex: 0
                        icon: "brand-docker"
                        text: "Containers"
                        checked: root.currentTabIndex === 0
                        onClicked: root.currentTabIndex = 0
                        pointSize: Style.fontSizeXS
                    }

                    NTabButton {
                        tabIndex: 1
                        text: "Images"
                        icon: "photo"
                        checked: root.currentTabIndex === 1
                        onClicked: root.currentTabIndex = 1
                        pointSize: Style.fontSizeXS
                    }

                    NTabButton {
                        tabIndex: 2
                        text: "Volumes"
                        icon: "database"
                        checked: root.currentTabIndex === 2
                        onClicked: root.currentTabIndex = 2
                        pointSize: Style.fontSizeXS
                    }

                    NTabButton {
                        tabIndex: 3
                        text: "Networks"
                        icon: "network"
                        checked: root.currentTabIndex === 3
                        onClicked: root.currentTabIndex = 3
                        pointSize: Style.fontSizeXS
                    }
                }
            }
        }

        StackLayout {
            id: contentColumns
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.currentTabIndex

            // Containers Tab
            Item {
                ListView {
                    id: containersList
                    anchors.fill: parent
                    model: containersModel
                    delegate: ContainerDelegate {
                        width: ListView.view.width
                        onRequestStart: id => startContainer(id)
                        onRequestStop: id => stopContainer(id)
                        onRequestRestart: id => restartContainer(id)
                        onRequestRemove: id => removeContainer(id)
                    }
                    spacing: Style.marginS
                    clip: true
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        active: containersList.moving
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: containersModel.count === 0
                    text: "No containers found"
                    color: Color.mOnSurfaceVariant
                }
            }

            // Images Tab
            Item {
                ListView {
                    id: imagesList
                    anchors.fill: parent
                    model: imagesModel
                    delegate: ImageDelegate {
                        width: ListView.view.width
                        onRequestRun: (repo, tag) => attemptRunImage(repo, tag)
                        onRequestRemove: id => removeImage(id)
                    }
                    spacing: Style.marginS
                    clip: true
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        active: imagesList.moving
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: imagesModel.count === 0
                    text: "No images found"
                    color: Color.mOnSurfaceVariant
                }
            }

            // Volumes Tab
            Item {
                ListView {
                    id: volumesList
                    anchors.fill: parent
                    model: volumesModel
                    delegate: VolumeDelegate {
                        width: ListView.view.width
                        onRequestRemove: name => removeVolume(name)
                    }
                    spacing: Style.marginS
                    clip: true
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        active: volumesList.moving
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: volumesModel.count === 0
                    text: "No volumes found"
                    color: Color.mOnSurfaceVariant
                }
            }

            // Networks Tab
            Item {
                ListView {
                    id: networksList
                    anchors.fill: parent
                    model: networksModel
                    delegate: NetworkDelegate {
                        width: ListView.view.width
                        onRequestRemove: id => removeNetwork(id)
                    }
                    spacing: Style.marginS
                    clip: true
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        active: networksList.moving
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: networksModel.count === 0
                    text: "No networks found"
                    color: Color.mOnSurfaceVariant
                }
            }
        }
    }

    Process {
        id: commandRunner
        onExited: {
            if (root._pendingCallback) {
                root._pendingCallback();
                root._pendingCallback = null;
            }
        }
        stdout: StdioCollector {}
    }

    Process {
        id: containerProcess
        command: ["docker", "ps", "-a", "--format", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                var data = DockerUtils.parseContainers(this.text);
                root._cachedContainers = data;
                containersModel.clear();
                data.forEach(function (c) {
                    containersModel.append(c);
                });
                imageProcess.running = true;
            }
        }
    }

    Process {
        id: imageProcess
        command: ["docker", "images", "--format", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                var data = DockerUtils.parseImages(this.text, root._cachedContainers);
                imagesModel.clear();
                data.forEach(function (img) {
                    imagesModel.append(img);
                });
            }
        }
    }

    Process {
        id: volumeProcess
        command: ["docker", "volume", "ls", "--format", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                var data = DockerUtils.parseVolumes(this.text);
                volumesModel.clear();
                data.forEach(function (v) {
                    volumesModel.append(v);
                });
            }
        }
    }

    Process {
        id: networkProcess
        command: ["docker", "network", "ls", "--format", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                var data = DockerUtils.parseNetworks(this.text);
                networksModel.clear();
                data.forEach(function (n) {
                    networksModel.append(n);
                });
            }
        }
    }

    Process {
        id: inspectProcess
        property string targetImage
        command: ["docker", "inspect", targetImage]
        stdout: StdioCollector {
            onStreamFinished: {
                var detectedPort = DockerUtils.parseExposedPorts(this.text);
                if (!detectedPort)
                    detectedPort = DockerUtils.guessDefaultPort(runImageDialog.imageRepo);

                if (runImageDialog.portField)
                    runImageDialog.portField.text = detectedPort;
                runImageDialog.placeholderPort = detectedPort;
                runImageDialog.open();
            }
        }
    }

    Process {
        id: portCheckProcess
        property string pendingPort
        property string pendingNetwork
        command: ["bash", "-c", "ss -tln | grep :" + pendingPort]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "") {
                    runImageDialog.errorMessage = "Port " + portCheckProcess.pendingPort + " is occupied on host.";
                } else {
                    runImageDialog.close();
                    // Retrieve stashed data
                    var pd = runImageDialog.pendingRunData || {};
                    finalizeRunImage(runImageDialog.imageRepo + ":" + runImageDialog.imageTag, portCheckProcess.pendingPort, portCheckProcess.pendingNetwork, pd.name, pd.envs);
                }
            }
        }
    }

    RunImageDialog {
        id: runImageDialog
        pluginApi: root.pluginApi
        networksModel: root.networksModel
        onRequestRun: (image, port, network, name, envs) => finalizeRunImage(image, port, network, name, envs)
        onRequestPortCheck: (port, network) => {
            portCheckProcess.pendingPort = port;
            portCheckProcess.pendingNetwork = network;
            portCheckProcess.running = true;
        }
    }
}
