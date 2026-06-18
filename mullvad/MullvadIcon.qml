import QtQuick
import qs.Commons
import qs.Widgets

Item {
	id: root
	property real pointSize: Style.fontSizeL
	property bool applyUiScale: true
	property bool crossed: false
	property color color: Color.mOnSurface

	implicitWidth: icon.implicitWidth
	implicitHeight: icon.implicitHeight

	NIcon {
		id: icon
		anchors.centerIn: parent
		icon: "shield"
		pointSize: root.pointSize
		applyUiScale: root.applyUiScale
		color: root.color
	}

	NIcon {
		visible: root.crossed
		anchors.centerIn: parent
		icon: "close"
		pointSize: root.pointSize * 0.7
		applyUiScale: root.applyUiScale
		color: root.color
	}
}
