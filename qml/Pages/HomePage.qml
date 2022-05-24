/*
 * Copyright (C) 2022  walking-octopus
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * cathode-tube is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


import QtQuick 2.9
import Ubuntu.Components 1.3
//import QtQuick.Controls 2.2
//import QtQuick.Layouts 1.3
//import Qt.labs.settings 1.0
import QtWebSockets 1.1

Page {
    id: homePage

    header: PageHeader {
        id: header
        flickable: scrollView.flickableItem
        title: i18n.tr('Home')

        leadingActionBar.actions: Action {
            iconName: "navigation-menu"
            text: i18n.tr("Menu")
            onTriggered: pStack.removePages(homePage)
            visible: !primaryPage.visible
        }

        trailingActionBar.actions: Action {
            iconName: "reload"
            text: i18n.tr("Reload")
            onTriggered: youtube.getFeed(youtube.currentFeedType)
        }

        extension: Sections {
            actions: [
                Action {
                    text: i18n.tr("Home")
                    onTriggered: youtube.getFeed("Home")
                },
                Action {
                    text: i18n.tr("Subscriptions")
                    onTriggered: youtube.getFeed("Subscriptions")
                },
                Action {
                    text: i18n.tr("Trending")
                    onTriggered: youtube.getFeed("Trending")
                }
            ]
        }
    }
    title: i18n.tr("YT Home")

    WebSocket {
        id: websocket
        url: "ws://localhost:8999"
        active: true

        onStatusChanged: function(status) {
            if (status == WebSocket.Open) {
                youtube.getFeed(youtube.currentFeedType);
            }
        }
        onTextMessageReceived: function(message) {
            let json = JSON.parse(message);
    
            switch (json.topic) {
                // STYLE: This use of fall-through doesn't look elegent

                case "feedEvent": videoModel.clear()

                case "continuationEvent": {
                    let feedType = json.payload.feedType;
                    let videos;
                    
                    switch (feedType) {
                        case "Home": {
                            videos = json.payload.videos;
                            break;
                        }

                        case "Subscriptions": {
                            videos = [];
                            for (const item of json.payload.items) {
                                print(item.date);

                                for (const video of item.videos) {
                                    videos.push(video);
                                }
                            }
                            break;
                        }
                            
                        // TODO: Use categories trending parsing
                        case "Trending": {
                            videos = [];
                            for (const item of json.payload.now.content) {
                                print(item.title);

                                for (let video of item.videos) {
                                    videos.push(video);
                                }
                            }
                            break;
                        }

                        default: {
                            print(`Error: invalid feed type ${feedType}`);
                            return;
                        }
                    }

                    for (const video of videos) {
                        videoModel.append({
                            "videoTitle": video.title,
                            "channel": video.channel,
                            "thumbnail": video.metadata.thumbnail.url,
                            "published": video.metadata.published,
                            "views": video.metadata.short_view_count_text.simple_text,
                            "duration": video.metadata.duration,
                            "id": video.id
                        });
                    }

                    youtube.currentFeedType = feedType;

                    break;
                }
            }
        }
    }

    QtObject {
        id: youtube
        property string currentFeedType: "Home"

        function getFeed(type) {
            websocket.sendTextMessage(`{ "topic": "GetFeed", "payload": "${type}" }`);
        }

        function getContinuation() {
            websocket.sendTextMessage(
                JSON.stringify({
                    topic: "GetContinuation"
                })
            );
        }
    }

    ListModel {
        id: videoModel
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent

        // TODO: Add pull to refresh and activity indicators

        ListView {
            id: view
            anchors.fill: parent

            model: videoModel
            delegate: ListItem {
                height: units.gu(8.5)
                onClicked: Qt.openUrlExternally(`https://www.youtube.com/watch?v=${id}`)

                ListItemLayout {
                    id: layout
                    anchors.centerIn: parent
                    
                    title.text: videoTitle
                    subtitle.text: channel.name
                    summary.text: duration ? `${duration.simple_text} | ${views} | ${published}` : `${views} | ${published}`

                    Image {
                        SlotsLayout.position: SlotsLayout.Leading
                        width: units.gu(10) // 16:9
                        height: units.gu(6)
                        source: thumbnail
                    }
                }
            }

            onAtYEndChanged: {
                if (view.atYEnd && videoModel.count > 0) {
                    print("Loading tail videos...");

                    if (youtube.currentFeedType == "Trending") { return; }
                    youtube.getContinuation();
                }
            }
        }
    }
}
