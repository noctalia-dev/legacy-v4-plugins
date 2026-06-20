import QtQuick
import qs.Commons

Item {
  id: root

  property var user: ({})
  property var stats: user?.stats || ({})
  property var layers: []

  readonly property string assetBaseUrl: "https://habitica-assets.s3.amazonaws.com/mobileApp/images/"
  readonly property bool hasAvatarData: !!user?.preferences
  readonly property string currentMount: user?.items?.currentMount || ""
  readonly property string currentPet: user?.items?.currentPet || ""
  readonly property bool hasCurrentMount: currentMount !== ""
  readonly property bool hasCurrentPet: currentPet !== ""
  readonly property real sourceWidth: 141
  readonly property real sourceHeight: 147
  readonly property real scaleRatio: Math.min(width / sourceWidth, height / sourceHeight)
  readonly property real characterPaddingTop: hasCurrentMount ? 0 : 24
  readonly property real mountOffsetY: hasCurrentMount ? 18 : 0
  readonly property real avatarLayerOffsetY: hasCurrentMount && currentMount.indexOf("Kangaroo") !== -1 ? 24 : 0
  readonly property string avatarSignature: JSON.stringify({
    preferences: user?.preferences || ({}),
    currentMount: currentMount,
    currentPet: currentPet,
    gear: user?.items?.gear || ({})
  })

  function pref(path, fallback) {
    var current = user?.preferences || ({})
    for (var i = 0; i < path.length; i++) {
      if (current === undefined || current === null || current[path[i]] === undefined) return fallback
      current = current[path[i]]
    }
    return current
  }

  function spriteSource(sprite) {
    return sprite ? assetBaseUrl + sprite + ".png" : ""
  }

  function addSprite(list, sprite) {
    if (sprite && sprite !== "undefined" && sprite !== "null" && list.indexOf(sprite) === -1) list.push(sprite)
  }

  function addGearSprite(list, sprite) {
    if (!sprite || sprite.match(/_base_0$/)) return
    addSprite(list, sprite)
  }

  function gear(slot) {
    var items = user?.items || ({})
    var allGear = items.gear || ({})
    var set = pref(["costume"], false) ? "costume" : "equipped"
    var current = allGear[set] || allGear.equipped || ({})
    return current[slot] || ""
  }

  function hair(slot) {
    var value = pref(["hair", slot], 0)
    if (!value) return ""
    return "hair_" + slot + "_" + value + "_" + pref(["hair", "color"], "brown")
  }

  function mountBody() {
    return hasCurrentMount ? "Mount_Body_" + currentMount : ""
  }

  function mountHead() {
    return hasCurrentMount ? "Mount_Head_" + currentMount : ""
  }

  function pet() {
    return hasCurrentPet ? "Pet-" + currentPet : ""
  }

  function characterLayers() {
    var list = []
    var size = pref(["size"], "slim")
    var chair = pref(["chair"], "none")
    var armor = gear("armor")
    var flower = pref(["hair", "flower"], 0)

    if (chair && chair !== "none") addSprite(list, "chair_" + chair)
    addGearSprite(list, gear("back"))
    addSprite(list, "skin_" + pref(["skin"], "ddc994") + (pref(["sleep"], false) ? "_sleep" : ""))
    addSprite(list, size + "_shirt_" + pref(["shirt"], "blue"))
    addSprite(list, "head_0")
    if (armor) addSprite(list, size + "_" + armor)
    addGearSprite(list, gear("back_collar"))
    addSprite(list, hair("bangs"))
    addSprite(list, hair("base"))
    addSprite(list, hair("mustache"))
    addSprite(list, hair("beard"))
    addGearSprite(list, gear("body"))
    addGearSprite(list, gear("eyewear"))
    addGearSprite(list, gear("head"))
    addGearSprite(list, gear("headAccessory"))
    if (flower) addSprite(list, "hair_flower_" + flower)
    addGearSprite(list, gear("shield"))
    addGearSprite(list, gear("weapon"))
    return list
  }

  Item {
    id: avatarViewport
    anchors.fill: parent
    visible: root.hasAvatarData

    Item {
      id: avatarCanvas
      width: root.sourceWidth
      height: root.sourceHeight
      x: (root.width - width * root.scaleRatio) / 2
      y: (root.height - height * root.scaleRatio) / 2
      scale: root.scaleRatio
      transformOrigin: Item.TopLeft

      Image {
        x: 0
        y: 0
        z: 0
        width: root.sourceWidth
        height: root.sourceHeight
        source: root.spriteSource("background_" + root.pref(["background"], "violet"))
        asynchronous: true
        cache: true
        smooth: false
      }
    }

    Item {
      id: characterSprites
      parent: avatarCanvas
      x: 24
      y: root.characterPaddingTop
      width: 90
      height: 90

      Image {
        x: 0
        y: root.mountOffsetY
        z: 1
        source: root.spriteSource(root.mountBody())
        asynchronous: true
        cache: true
        smooth: false
        visible: root.hasCurrentMount
      }

      Repeater {
        model: root.layers

        Image {
          x: 0
          y: root.avatarLayerOffsetY
          z: 2
          source: root.spriteSource(modelData)
          asynchronous: true
          cache: true
          smooth: false
        }
      }

      Image {
        x: 0
        y: root.mountOffsetY
        z: 3
        source: root.spriteSource(root.mountHead())
        asynchronous: true
        cache: true
        smooth: false
        visible: root.hasCurrentMount
      }

    }

    Image {
      parent: avatarCanvas
      x: 0
      y: root.sourceHeight - implicitHeight
      z: 4
      source: root.spriteSource(root.pet())
      asynchronous: true
      cache: true
      smooth: false
      visible: root.hasCurrentPet
    }
  }

  onAvatarSignatureChanged: layers = characterLayers()

  Component.onCompleted: layers = characterLayers()
}
