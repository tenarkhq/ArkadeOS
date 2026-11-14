/*
    ArkadeOS welcome screen, shown after login while the desktop loads (round
    8, approved 2026-11-14: "így jó"). The Égkék wallpaper blurred and dimmed,
    on it the Start mark, the ARKADEOS word (Inter Light, capitals, spaced as
    the boot screen's) and a thin glass-blue bar that fills as the desktop
    loads; the whole fades in, and the desktop takes over when it is ready.
    No other words, so it reads the same in every language (T010).
    Plasma sets stage from 1 (shown) to 6 (the desktop is there, the splash
    closes).
*/

import QtQuick
import QtQuick.Effects

Rectangle {
    id: root
    color: "#03080d"

    property int stage

    Image {
        id: wallpaper
        anchors.fill: parent
        source: "file:///usr/share/wallpapers/ArkadeOS-Egkek/contents/images/2560x1600.jxl"
        sourceSize: Qt.size(1280, 800)
        fillMode: Image.PreserveAspectCrop
        visible: false
    }
    // blurred, a little more saturated, and dimmed to 45 %
    MultiEffect {
        source: wallpaper
        anchors.fill: parent
        scale: 1.1
        blurEnabled: true
        blurMax: 64
        blur: 1
        saturation: 0.2
    }
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.55
    }

    Column {
        id: content
        anchors.centerIn: parent
        spacing: root.height * 0.055
        opacity: 0
        scale: 0.96
        Component.onCompleted: { opacity = 1; scale = 1 }
        Behavior on opacity { NumberAnimation { duration: 1200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 1200; easing.type: Easing.OutCubic } }

        // the Start mark in its large optical size, dark material
        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.height * 0.28
            height: width
            sourceSize: Qt.size(width, height)
            source: "file:///usr/share/icons/arkadeos-glass-dark/marks/l/arkadeos-logo.svg"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            // the spacing after the last letter, balanced on the left
            leftPadding: font.letterSpacing
            text: "ARKADEOS"
            color: "#eef6fd"
            font.family: "Inter"
            font.weight: Font.Light
            font.pixelSize: root.height * 0.055
            font.letterSpacing: font.pixelSize * 0.34
        }

        // the bar fills as Plasma's loading steps pass
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.width * 0.28
            height: Math.max(2, Math.round(root.height * 0.005))
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.14)
            clip: true

            Rectangle {
                height: parent.height
                radius: parent.radius
                width: parent.width * Math.min(1, Math.max(0, root.stage - 1) / 5)
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#5aaeea" }
                    GradientStop { position: 1; color: "#bfe6ff" }
                }
            }
        }
    }
}
