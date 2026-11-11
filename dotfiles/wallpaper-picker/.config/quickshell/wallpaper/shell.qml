// Coverflow wallpaper picker (slanted cards), ported from pocket-dots'
// WallpaperPicker.qml (https://github.com/diegoMalagrida/pocket-dots, GPL-3.0).
// Standalone: runs as its own Quickshell config, reads ~/Wallpapers and applies
// the choice with the wallpaper-set script (swaybg). Colours come from Colors.qml,
// which theme-render generates from the central colours file.
import QtQuick
import QtQuick.Effects
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property bool open: false
    readonly property string home: Quickshell.env("HOME")
    readonly property string wallsDir: home + "/Wallpapers"
    readonly property string thumbsDir: home + "/.cache/wallpaper-thumbs"
    readonly property string thumbsScript: Quickshell.shellDir + "/wall-thumbs.sh"

    // Thumbnails are named "<original file>.jpg", so dropping the suffix gives the original
    function originalOf(thumbName) {
        return root.wallsDir + "/" + String(thumbName).replace(/\.jpg$/, "");
    }

    // Crossfade: the new wallpaper fades in over the old one (a layer above swaybg, below windows),
    // swaybg is switched underneath, then the layer fades out again.
    property string fadePath: ""
    property bool fadeShow: false

    function apply(thumbName) {
        root.open = false;
        root.fadePath = root.originalOf(thumbName);
        root.fadeShow = true; // fadeIn runs, then onFadeInDone() applies the wallpaper
    }
    function onFadeInDone() {
        Quickshell.execDetached(["wallpaper-set", root.fadePath]);
        settle.restart();
    }
    Timer {
        id: settle
        interval: 900 // wallpaper-set swaps swaybg after ~0.4 s
        onTriggered: root.fadeShow = false
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: fadeImg.opacity > 0
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "wallpaperFade"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {} // never takes input

            Image {
                id: fadeImg
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: root.fadePath ? "file://" + root.fadePath : ""
                asynchronous: true
                cache: false
                opacity: 0
                states: State {
                    name: "shown"
                    when: root.fadeShow && fadeImg.status === Image.Ready
                    PropertyChanges { fadeImg.opacity: 1 }
                }
                transitions: [
                    Transition {
                        to: "shown"
                        SequentialAnimation {
                            NumberAnimation { property: "opacity"; duration: 450; easing.type: Easing.OutCubic }
                            ScriptAction { script: if (modelData === Quickshell.screens[0]) root.onFadeInDone() }
                        }
                    },
                    Transition {
                        from: "shown"
                        NumberAnimation { property: "opacity"; duration: 350; easing.type: Easing.InCubic }
                    }
                ]
            }
        }
    }

    Process {
        id: thumbsProc
        command: ["bash", root.thumbsScript, root.wallsDir, root.thumbsDir]
        onExited: {
            // The model's watcher doesn't notice the cache folder being created, so re-point it once
            if (wallModel.count === 0) {
                wallModel.folder = "";
                wallModel.folder = "file://" + root.thumbsDir;
            }
        }
    }
    function refreshThumbs() {
        thumbsProc.running = false;
        thumbsProc.running = true;
    }
    Component.onCompleted: root.refreshThumbs()

    FolderListModel {
        id: wallModel
        folder: "file://" + root.thumbsDir
        nameFilters: ["*.jpg"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        // Stay mapped until the fade-out finishes
        visible: root.open || stage.opacity > 0
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "wallpaperCarousel"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Item {
            id: stage
            anchors.fill: parent
            focus: true
            opacity: root.open ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: root.open ? 210 : 110
                    easing.type: root.open ? Easing.OutCubic : Easing.InCubic
                }
            }

            Connections {
                target: root
                function onOpenChanged() {
                    if (!root.open) return;
                    stage.forceActiveFocus();
                    root.refreshThumbs();
                }
            }

            Keys.onEscapePressed: root.open = false
            Keys.onLeftPressed: carousel.decrementCurrentIndex()
            Keys.onRightPressed: carousel.incrementCurrentIndex()
            Keys.onReturnPressed: carousel.applyCurrent()
            Keys.onEnterPressed: carousel.applyCurrent()
            WheelHandler {
                onWheel: e => {
                    if (e.angleDelta.y > 0 || e.angleDelta.x > 0) carousel.decrementCurrentIndex();
                    else carousel.incrementCurrentIndex();
                }
            }

            // Click on an empty area closes
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: root.open = false
            }

            ListView {
                id: carousel
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    verticalCenterOffset: 12
                }
                height: 560
                orientation: ListView.Horizontal
                model: wallModel
                property real iw: 720 // Hero card width
                property real ih: 406 // Hero card height (~16:9)
                property real skew: -0.35
                property real bw: 3
                property real slotW: 360 // Fixed scroll step
                property real sideBase: 0.56 // Scale of the first neighbour
                readonly property real imgW: iw + ih * Math.abs(skew) + 12
                spacing: 0
                clip: false
                cacheBuffer: 2500
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: (width - slotW) / 2
                preferredHighlightEnd: (width + slotW) / 2
                highlightMoveDuration: 420
                highlightMoveVelocity: 3000
                snapMode: ListView.SnapToItem
                boundsBehavior: Flickable.StopAtBounds
                maximumFlickVelocity: 6000

                function applyCurrent() {
                    if (currentIndex < 0 || wallModel.count <= currentIndex) return;
                    root.apply(wallModel.get(currentIndex, "fileName"));
                }

                delegate: Item {
                    id: slot
                    width: carousel.slotW
                    height: carousel.height
                    // Continuous distance to the centre of the viewport, in slots
                    readonly property real d: (x + width / 2 - (carousel.contentX + carousel.width / 2)) / carousel.slotW
                    readonly property real ad: Math.abs(d)
                    readonly property real sc: ad <= 1
                        ? carousel.sideBase + (1 - carousel.sideBase) * Math.pow(1 - ad, 1.35)
                        : carousel.sideBase * Math.pow(0.86, ad - 1)
                    z: Math.round(100 - ad * 10)
                    opacity: Math.max(0, Math.min(1, 1.15 - 0.34 * ad))

                    Item {
                        id: card
                        anchors.centerIn: parent
                        width: carousel.iw
                        height: carousel.ih
                        scale: slot.sc
                        transformOrigin: Item.Center
                        // Shear around the vertical centre
                        transform: Matrix4x4 {
                            matrix: Qt.matrix4x4(1, carousel.skew, 0, -carousel.skew * carousel.ih / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Colors.base
                            border.width: 1
                            border.color: slot.ad < 0.5 ? Colors.accent : Colors.border
                        }
                        // Inverse shear keeps the image itself straight
                        Item {
                            anchors.fill: parent
                            anchors.margins: carousel.bw
                            clip: true
                            Image {
                                anchors.centerIn: parent
                                width: carousel.imgW
                                height: carousel.ih
                                fillMode: Image.PreserveAspectCrop
                                source: model.fileUrl
                                asynchronous: true
                                cache: true
                                mipmap: true
                                sourceSize: Qt.size(carousel.imgW, carousel.ih)
                                transform: Matrix4x4 {
                                    matrix: Qt.matrix4x4(1, -carousel.skew, 0, carousel.skew * carousel.ih / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: slot.ad < 0.5 ? carousel.applyCurrent() : (carousel.currentIndex = index)
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: wallModel.count === 0
                text: "No wallpapers in ~/Wallpapers"
                color: Colors.text
                font.pixelSize: 16
                font.family: "JetBrains Mono Nerd Font"
                opacity: 0.85
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowBlur: 1.0
                    blurMax: 16
                    shadowVerticalOffset: 0
                }
            }
        }
    }

    IpcHandler {
        target: "picker"

        function toggle(): void {
            root.open = !root.open;
        }
    }
}
