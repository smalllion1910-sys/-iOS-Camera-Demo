import SwiftUI
import AVKit
import PhotosUI

struct CameraDemo: View {
    @State private var selectedVideo: PhotosPickerItem?
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 20) {
            Text("MEME MODE")
                .font(.largeTitle)
                .bold()

            Text("PRERECORDED VIDEO DEMO")
                .font(.caption)

            PhotosPicker(
                "Choose Meme Video",
                selection: $selectedVideo,
                matching: .videos
            )

            if let player = player {
                VideoPlayer(player: player)
                    .frame(height: 300)
            }
        }
        .padding()
        .onChange(of: selectedVideo) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent("meme.mp4")

                    try? data.write(to: url)
                    player = AVPlayer(url: url)
                    player?.play()
                }
            }
        }
    }
}
