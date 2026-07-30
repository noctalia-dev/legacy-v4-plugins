import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.System
import qs.Widgets

ColumnLayout {
	id: root
	spacing: Style.marginM

	property var pluginApi: null
	property var widgetSettings: null

    // --- Read from widgetSettings.data ---
    property string scrambleSpeed: widgetSettings?.data?.scrambleSpeed ?? "medium"
    property string scrambleChars: widgetSettings?.data?.scrambleChars ?? "mix"
    property bool showAuthor: widgetSettings?.data?.showAuthor ?? true
    property bool autoChangeDaily: widgetSettings?.data?.autoChangeDaily ?? true
    property var userQuotes: widgetSettings?.data?.userQuotes ?? []
    property string quoteFont: widgetSettings?.data?.quoteFont ?? ""
    property string authorFont: widgetSettings?.data?.authorFont ?? ""
    property bool showBackground: widgetSettings?.data?.showBackground ?? true
    property bool showGradientOverlay: widgetSettings?.data?.showGradientOverlay ?? true
    property string gradientDirection: widgetSettings?.data?.gradientDirection ?? "vertical"
    property string quoteColor: widgetSettings?.data?.quoteColor ?? "primary"
    property string textAlign: widgetSettings?.data?.textAlign ?? "left"

    function saveSettings() {
        if (!widgetSettings || !widgetSettings.data) return;
        widgetSettings.data.scrambleSpeed = scrambleSpeed;
        widgetSettings.data.scrambleChars = scrambleChars;
        widgetSettings.data.showAuthor = showAuthor;
        widgetSettings.data.autoChangeDaily = autoChangeDaily;
        widgetSettings.data.userQuotes = userQuotes;
        widgetSettings.data.quoteFont = quoteFont;
        widgetSettings.data.authorFont = authorFont;
        widgetSettings.data.showBackground = showBackground;
        widgetSettings.data.showGradientOverlay = showGradientOverlay;
        widgetSettings.data.gradientDirection = gradientDirection;
        widgetSettings.data.quoteColor = quoteColor;
        widgetSettings.data.textAlign = textAlign;
        widgetSettings.save();
    }

	// --- Header ---
	NLabel {
		label: "Daily Quote"
		description: "Widget de frases diarias con efecto scramble decode"
		Layout.fillWidth: true
	}

	NDivider { Layout.fillWidth: true }

	// --- User Quotes List ---
	NLabel {
		label: "Tus frases"
		description: userQuotes.length + " frases personalizadas"
		Layout.fillWidth: true
	}

ListView {
    id: quotesList
    Layout.fillWidth: true
    Layout.preferredHeight: Math.min(quotesList.contentHeight, 220)
    Layout.minimumHeight: root.userQuotes.length > 0 ? 60 : 0
    Layout.maximumHeight: 220
    clip: true
    spacing: Style.marginS
    model: root.userQuotes
    visible: root.userQuotes.length > 0

    delegate: Rectangle {
        id: quoteCard
        width: quotesList.width
        height: quoteContent.height + Style.marginM * 2
        color: Color.mSurfaceVariant
        radius: Style.radiusM

        RowLayout {
            id: quoteRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.marginM
            spacing: Style.marginS

            ColumnLayout {
                id: quoteContent
                Layout.fillWidth: true
                spacing: 2

                NText {
                    text: modelData.text
                    color: Color.mOnSurface
                    pointSize: Style.fontSizeS
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
                NText {
                    text: modelData.author ? "\u2014 " + modelData.author : ""
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeXS
                    visible: modelData.author && modelData.author !== ""
                    Layout.fillWidth: true
                }
            }

            NIconButton {
                icon: "close"
                color: hovering ? Color.mError : Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignTop
                onClicked: {
                    var quotes = root.userQuotes.slice();
                    quotes.splice(index, 1);
                    root.userQuotes = quotes;
                    root.saveSettings();
                }
            }
        }
    }
}

	NDivider { Layout.fillWidth: true }

	// --- Add new quote ---
	NLabel {
		label: "Agregar frase"
		Layout.fillWidth: true
	}

	ColumnLayout {
		Layout.fillWidth: true
		spacing: Style.marginS

		NTextInput {
			id: newQuoteInput
			Layout.fillWidth: true
			placeholderText: "Escribe tu frase aqui..."
		}

		NTextInput {
			id: newAuthorInput
			Layout.fillWidth: true
			placeholderText: "Autor (opcional)..."
		}

		NButton {
			text: "+ Agregar"
			Layout.fillWidth: true
			onClicked: {
				if (newQuoteInput.text.trim() !== "") {
					var quotes = root.userQuotes.slice();
					quotes.push({
						"text": newQuoteInput.text.trim(),
						"author": newAuthorInput.text.trim()
					});
					root.userQuotes = quotes;
					root.saveSettings();
					newQuoteInput.text = "";
					newAuthorInput.text = "";
				}
			}
		}
	}

    NDivider { Layout.fillWidth: true }

    // --- Typography ---
    NLabel {
        label: "Tipografia"
        Layout.fillWidth: true
    }

    NSearchableComboBox {
        Layout.fillWidth: true
        label: "Fuente de la frase"
        model: FontService.availableFonts
        currentKey: root.quoteFont
        placeholder: "Predeterminada del sistema"
        searchPlaceholder: "Buscar fuente..."
        popupHeight: 320
        minimumWidth: 260
        onSelected: function(key) {
            root.quoteFont = key;
            root.saveSettings();
        }
        defaultValue: ""
    }

    NSearchableComboBox {
        Layout.fillWidth: true
        label: "Fuente del autor"
        model: FontService.availableFonts
        currentKey: root.authorFont
        placeholder: "Predeterminada del sistema"
        searchPlaceholder: "Buscar fuente..."
        popupHeight: 320
        minimumWidth: 260
        onSelected: function(key) {
            root.authorFont = key;
            root.saveSettings();
        }
        defaultValue: ""
    }

    NColorChoice {
        Layout.fillWidth: true
        label: "Color del texto"
        currentKey: root.quoteColor
        onSelected: function(key) {
            root.quoteColor = key;
            root.saveSettings();
        }
        defaultValue: "primary"
    }

    NComboBox {
        Layout.fillWidth: true
        label: "Alineacion"
        model: [
            { "key": "left", "name": "Izquierda" },
            { "key": "center", "name": "Centro" },
            { "key": "right", "name": "Derecha" }
        ]
        currentKey: root.textAlign
        onSelected: function(key) {
            root.textAlign = key;
            root.saveSettings();
        }
    }

    NDivider { Layout.fillWidth: true }

    // --- Options ---
	NLabel {
		label: "Opciones"
		Layout.fillWidth: true
	}

	NComboBox {
		Layout.fillWidth: true
		label: "Velocidad decodificacion"
		model: [
			{ "key": "fast", "name": "Rapido" },
			{ "key": "medium", "name": "Medio" },
			{ "key": "slow", "name": "Lento" }
		]
		currentKey: root.scrambleSpeed
		onSelected: function(key) {
			root.scrambleSpeed = key;
			root.saveSettings();
		}
	}

	NComboBox {
		Layout.fillWidth: true
		label: "Estilo caracteres"
		model: [
			{ "key": "mix", "name": "Mixto" },
			{ "key": "ascii", "name": "ASCII" },
			{ "key": "symbols", "name": "Simbolos" }
		]
		currentKey: root.scrambleChars
		onSelected: function(key) {
			root.scrambleChars = key;
			root.saveSettings();
		}
	}

    NToggle {
        Layout.fillWidth: true
        label: "Mostrar fondo"
        checked: root.showBackground
        defaultValue: true
        onToggled: function(val) {
            root.showBackground = val;
            root.saveSettings();
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: "Gradiente sobre wallpaper"
        description: "Suave velo para mejorar legibilidad (se adapta al modo claro/oscuro)"
        visible: !root.showBackground
        checked: root.showGradientOverlay
        defaultValue: true
        onToggled: function(val) {
            root.showGradientOverlay = val;
            root.saveSettings();
        }
    }

    NComboBox {
        Layout.fillWidth: true
        visible: !root.showBackground && root.showGradientOverlay
        label: "Direccion del gradiente"
        model: [
            { "key": "vertical", "name": "Vertical" },
            { "key": "horizontal", "name": "Horizontal" }
        ]
        currentKey: root.gradientDirection
        onSelected: function(key) {
            root.gradientDirection = key;
            root.saveSettings();
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: "Mostrar autor"
		checked: root.showAuthor
		defaultValue: true
		onToggled: function(val) {
			root.showAuthor = val;
			root.saveSettings();
		}
	}

	NToggle {
		Layout.fillWidth: true
		label: "Cambio automatico diario"
		checked: root.autoChangeDaily
		defaultValue: true
		onToggled: function(val) {
			root.autoChangeDaily = val;
			root.saveSettings();
		}
	}
}
