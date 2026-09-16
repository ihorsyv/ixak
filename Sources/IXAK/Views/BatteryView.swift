import SwiftUI

struct BatteryView: View {
    @State private var battery: BatteryInfo?
    @State private var noBattery = false

    var body: some View {
        Form {
            if let battery {
                Section("Health / Здоровье") {
                    LabeledContent("Condition / Состояние", value: battery.condition)
                    LabeledContent("Health / Износ", value: String(format: "%.1f%%", battery.healthPercent))
                    LabeledContent("Cycle Count / Циклы заряда", value: "\(battery.cycleCount)")
                    LabeledContent("Design Capacity / Проектная ёмкость", value: "\(battery.designCapacity) mAh")
                    LabeledContent("Current Max Capacity / Текущая максимальная ёмкость", value: "\(battery.maxCapacity) mAh")
                }

                Section("Live Status / Текущее состояние") {
                    LabeledContent("Charge / Заряд", value: String(format: "%.0f%%", battery.chargePercent))
                    LabeledContent("Charging / Заряжается", value: battery.isCharging ? "Yes / Да" : "No / Нет")
                    if let temp = battery.temperatureCelsius {
                        LabeledContent("Temperature / Температура", value: String(format: "%.1f°C", temp))
                    }
                }
            } else if noBattery {
                Text("No battery detected (desktop Mac) / Батарея не обнаружена (настольный Mac)")
            } else {
                ProgressView()
            }

            Button("Refresh / Обновить") { load() }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { load() }
    }

    private func load() {
        battery = BatteryInfo.read()
        noBattery = (battery == nil)
    }
}

#Preview {
    BatteryView()
}
