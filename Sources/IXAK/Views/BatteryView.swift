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

                if let hint = recommendation(for: battery) {
                    Section("Recommendation / Рекомендация") {
                        Text(hint)
                            .font(.callout)
                            .foregroundStyle(.orange)
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

    private func recommendation(for battery: BatteryInfo) -> String? {
        if battery.condition.hasPrefix("Service Recommended") {
            return "Apple reports a permanent fault — book a Genius Bar / authorized service appointment. / Apple сообщает о постоянной неисправности — обратитесь в авторизованный сервис."
        }
        if battery.healthPercent < 80 {
            return "Battery health is below 80% — expect reduced runtime; consider a battery replacement. / Износ батареи выше 20% — время работы заметно снижено, стоит задуматься о замене."
        }
        if let temp = battery.temperatureCelsius, temp > 40 {
            return "Battery temperature is high (\(String(format: "%.0f", temp))°C) — ensure vents aren't blocked and avoid charging in direct sun/heat. / Высокая температура батареи — проверьте вентиляцию и не заряжайте на солнце/в тепле."
        }
        return nil
    }
}

#Preview {
    BatteryView()
}
