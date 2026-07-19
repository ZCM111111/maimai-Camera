import SwiftUI

struct BridgeView: View {
    @StateObject private var vm = BridgeViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Maimai Bridge")
                .font(.largeTitle).foregroundColor(.white)

            Text("PC 连接 IP:")
                .foregroundColor(.gray)
            Text(vm.ipAddress)
                .font(.title2.monospaced()).foregroundColor(.green)

            Text("端口: 8888")
                .foregroundColor(.gray)

            Spacer()

            Button(action: { vm.streaming ? vm.stop() : vm.start() }) {
                Circle()
                    .fill(vm.streaming ? .red : .green)
                    .frame(width: 80, height: 80)
                    .overlay(Text(vm.streaming ? "停止" : "开始").foregroundColor(.white))
            }

            Text(vm.streaming ? "推流中..." : "等待开始")
                .foregroundColor(.gray)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .onAppear { vm.setup() }
    }
}
