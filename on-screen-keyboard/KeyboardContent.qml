import QtQuick
import QtQuick.Layouts
import qs.Commons

Item {
    id: root

    property var layoutData: null
    property bool showFunctionKeys: true
    property int shiftMode: 0

    signal keyPressed(int keycode, string keytype)
    signal keyReleased(int keycode, string keytype)

    implicitWidth: keyRowsLayout.implicitWidth
    implicitHeight: keyRowsLayout.implicitHeight

    ColumnLayout {
        id: keyRowsLayout
        anchors.fill: parent
        spacing: 5

        Repeater {
            model: root.layoutData?.keys || []

            delegate: RowLayout {
                id: keyRow
                required property var modelData
                required property int index
                spacing: 5

                // Hide function row if disabled
                visible: index !== 0 || root.showFunctionKeys
                Layout.preferredHeight: visible ? implicitHeight : 0

                Repeater {
                    model: modelData

                    delegate: KeyButton {
                        required property var modelData
                        keyData: modelData
                        shiftMode: root.shiftMode

                        onPressed: (code, type) => {
                            root.keyPressed(code, type);
                        }

                        onReleased: (keycode, keytype) => {
                            root.keyReleased(keycode, keytype);
                        }
                    }
                }
            }
        }
    }
}
