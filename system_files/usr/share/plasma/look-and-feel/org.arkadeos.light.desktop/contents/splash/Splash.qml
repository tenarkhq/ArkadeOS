/*
    ArkadeOS splash screen (T083, Roland 2026-11-04: A, the boot screen goes
    on). The ArkadeOS wordmark lit white, as the boot screen (T082,
    Fénycsíkok) leaves it, with the white streak lapping through it; under it
    one dot per loading step in the Ark colours. No words, so it reads the
    same in every language (T010).
    Plasma sets stage from 1 (shown) to 6 (the desktop is there, the splash
    closes); the dots light at 2-5.
*/

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Rectangle {
    id: root
    color: "black"

    property int stage

    // The wordmark is drawn in units of its own 305-wide letter box and is
    // 18.75 percent of the screen's width, as on the boot screen.
    readonly property real u: width * 0.1875 / 305
    readonly property var letters: [
        "M1.28 64 17.664 18.56H25.088L41.472 64H35.456L30.912 51.072H11.84L7.296 64ZM13.696 45.696H29.056L21.376 23.36Z",
        "M46.872 64V30.08H51.608L51.864 38.656L51.352 38.464Q51.992 34.112 54.136 32.096Q56.28 30.08 59.864 30.08H63.192V35.2H59.928Q57.368 35.2 55.672 36.128Q53.976 37.056 53.112 38.88Q52.248 40.704 52.248 43.52V64Z",
        "M70.128 64V18.56H75.504V48.32L92.016 30.08H99.184L85.808 44.48L99.76 64H93.232L82.16 48.128L75.504 55.168V64Z",
        "M116.04 64.768Q110.792 64.768 107.688 62.336Q104.584 59.904 104.584 55.552Q104.584 51.2 107.144 48.704Q109.704 46.208 115.272 45.184L127.304 42.944Q127.304 38.656 125.288 36.544Q123.272 34.432 119.24 34.432Q115.72 34.432 113.672 36Q111.624 37.568 110.856 40.512L105.16 40.064Q106.12 35.264 109.8 32.288Q113.48 29.312 119.24 29.312Q125.768 29.312 129.224 32.992Q132.68 36.672 132.68 43.136V57.152Q132.68 58.304 133.096 58.784Q133.512 59.264 134.472 59.264H135.816V64Q135.56 64.064 134.984 64.096Q134.408 64.128 133.768 64.128Q131.464 64.128 130.024 63.392Q128.584 62.656 127.944 61.088Q127.304 59.52 127.304 56.96L127.944 57.088Q127.496 59.264 125.768 61.024Q124.04 62.784 121.48 63.776Q118.92 64.768 116.04 64.768ZM116.552 60.032Q119.944 60.032 122.344 58.72Q124.744 57.408 126.024 55.136Q127.304 52.864 127.304 50.048V47.616L116.296 49.664Q112.84 50.304 111.528 51.616Q110.216 52.928 110.216 55.04Q110.216 57.408 111.912 58.72Q113.608 60.032 116.552 60.032Z",
        "M153.184 64.768Q148.768 64.768 145.536 62.592Q142.304 60.416 140.576 56.448Q138.848 52.48 138.848 47.04Q138.848 41.6 140.576 37.632Q142.304 33.664 145.536 31.488Q148.768 29.312 153.184 29.312Q156.576 29.312 159.392 30.752Q162.208 32.192 163.616 34.816V18.56H168.992V64H164.128L163.936 58.88Q162.528 61.632 159.648 63.2Q156.768 64.768 153.184 64.768ZM154.272 59.648Q157.28 59.648 159.36 58.112Q161.44 56.576 162.528 53.728Q163.616 50.88 163.616 47.04Q163.616 43.072 162.528 40.256Q161.44 37.44 159.36 35.936Q157.28 34.432 154.272 34.432Q149.792 34.432 147.136 37.792Q144.48 41.152 144.48 47.04Q144.48 52.864 147.136 56.256Q149.792 59.648 154.272 59.648Z",
        "M191.48 64.768Q186.68 64.768 183.192 62.592Q179.704 60.416 177.816 56.416Q175.928 52.416 175.928 47.04Q175.928 41.664 177.816 37.696Q179.704 33.728 183.128 31.52Q186.552 29.312 191.224 29.312Q195.64 29.312 199.032 31.392Q202.424 33.472 204.312 37.44Q206.2 41.408 206.2 47.104V48.704H181.56Q181.88 54.144 184.472 56.896Q187.064 59.648 191.48 59.648Q194.808 59.648 196.952 58.08Q199.096 56.512 199.928 53.952L205.688 54.4Q204.344 58.944 200.6 61.856Q196.856 64.768 191.48 64.768ZM181.56 43.968H200.312Q199.928 39.04 197.464 36.736Q195 34.432 191.224 34.432Q187.32 34.432 184.792 36.832Q182.264 39.232 181.56 43.968Z",
        "M235.221 65.024Q228.192 65.024 223.117 62.15Q218.042 59.277 215.341 53.965Q212.64 48.653 212.64 41.344Q212.64 34.035 215.341 28.691Q218.042 23.347 223.104 20.442Q228.167 17.536 235.219 17.536Q242.318 17.536 247.364 20.442Q252.41 23.347 255.11 28.691Q257.811 34.035 257.811 41.344Q257.811 48.653 255.11 53.965Q252.41 59.277 247.364 62.15Q242.319 65.024 235.221 65.024ZM235.208 55.91Q238.726 55.91 241.218 54.187Q243.71 52.464 245.039 49.221Q246.368 45.978 246.368 41.344Q246.368 36.71 245.037 33.433Q243.706 30.156 241.21 28.403Q238.714 26.65 235.195 26.65Q231.725 26.65 229.233 28.403Q226.741 30.156 225.412 33.433Q224.083 36.71 224.083 41.344Q224.083 45.978 225.414 49.221Q226.746 52.464 229.242 54.187Q231.738 55.91 235.208 55.91Z",
        "M282.539 65.024Q276.472 65.024 272.158 63.04Q267.845 61.056 265.445 57.44Q263.045 53.824 262.712 48.909L273.848 48.371Q274.194 50.842 275.269 52.57Q276.344 54.298 278.168 55.181Q279.992 56.064 282.667 56.064Q284.843 56.064 286.366 55.565Q287.89 55.066 288.69 54.029Q289.49 52.992 289.49 51.456Q289.49 50.061 288.805 48.992Q288.12 47.923 286.155 47.059Q284.19 46.195 280.338 45.363Q274.322 44.07 270.629 42.394Q266.936 40.717 265.253 38.106Q263.57 35.494 263.57 31.488Q263.57 27.341 265.675 24.198Q267.781 21.056 271.736 19.296Q275.691 17.536 281.234 17.536Q287.096 17.536 291.09 19.552Q295.083 21.568 297.323 25.088Q299.563 28.608 300.024 33.229L288.99 33.715Q288.811 31.475 287.819 29.869Q286.827 28.262 285.15 27.379Q283.474 26.496 281.106 26.496Q278.11 26.496 276.434 27.77Q274.757 29.043 274.757 31.13Q274.757 32.678 275.544 33.722Q276.331 34.765 278.2 35.488Q280.069 36.211 283.384 36.864Q289.899 38.067 293.694 40.045Q297.49 42.022 299.083 44.736Q300.677 47.45 300.677 50.97Q300.677 55.296 298.501 58.464Q296.325 61.632 292.254 63.328Q288.184 65.024 282.539 65.024Z"
    ]
    // Each letter's middle, where the streak lights it.
    readonly property var middles: [20, 55, 85, 120, 158, 195, 245, 290]
    readonly property var colours: ["#F43F5E", "#F59E0B", "#22C55E", "#C9CCF2"]
    // The white streak's head, in wordmark units; one lap every 2 seconds.
    property real head: -60

    NumberAnimation on head {
        from: -60
        to: 370
        duration: 2000
        loops: Animation.Infinite
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: 400 } }

        // The wordmark's box from its top (unit 0) down; the letters start at 16.
        Item {
            id: mark
            width: 305 * root.u
            height: 100 * root.u
            x: (root.width - width) / 2
            y: root.height * 0.45 - 26 * root.u - 16 * root.u

            Repeater {
                model: root.letters.length
                Item {
                    id: letter
                    required property int index
                    readonly property real glow: Math.max(0, 1 - Math.abs(root.head - root.middles[index]) / 45)
                    anchors.fill: parent

                    Shape {
                        id: shape
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: "#F4F4F6"
                            strokeColor: "transparent"
                            scale: Qt.size(root.u, root.u)
                            PathSvg { path: root.letters[letter.index] }
                        }
                    }
                    MultiEffect {
                        source: shape
                        anchors.fill: shape
                        autoPaddingEnabled: true
                        opacity: 0.82 + 0.18 * letter.glow
                        shadowEnabled: true
                        shadowColor: "#F43F5E"
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                        blurMax: 64
                        shadowBlur: Math.min(1, (6 + 26 * letter.glow) * root.u / 64)
                    }
                }
            }

            // The white streak under the letters.
            Rectangle {
                id: streak
                x: (root.head - 110) * root.u
                y: 70 * root.u
                width: 110 * root.u
                height: Math.max(1, 1.6 * root.u)
                visible: false
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#00ffffff" }
                    GradientStop { position: 1; color: "#e6ffffff" }
                }
            }
            MultiEffect {
                source: streak
                x: streak.x
                y: streak.y
                width: streak.width
                height: streak.height
                autoPaddingEnabled: true
                shadowEnabled: true
                shadowColor: "white"
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
                blurMax: 32
                shadowBlur: Math.min(1, 12 * root.u / 32)
            }

            // One dot per loading step, lit in its colour when it is done.
            Repeater {
                model: 4
                Item {
                    id: step
                    required property int index
                    readonly property bool done: root.stage >= index + 2
                    width: 4.4 * root.u
                    height: width
                    x: mark.width / 2 + (index - 1.5) * 14 * root.u - width / 2
                    y: 94 * root.u - height / 2

                    Rectangle {
                        id: dot
                        anchors.fill: parent
                        radius: width / 2
                        color: step.done ? root.colours[step.index] : "white"
                        visible: false
                    }
                    MultiEffect {
                        source: dot
                        anchors.fill: dot
                        autoPaddingEnabled: true
                        opacity: step.done ? 1 : 0.18
                        shadowEnabled: step.done
                        shadowColor: root.colours[step.index]
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                        blurMax: 32
                        shadowBlur: Math.min(1, 10 * root.u / 32)
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                    }
                }
            }
        }
    }
}
