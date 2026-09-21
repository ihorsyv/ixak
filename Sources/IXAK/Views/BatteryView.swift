import SwiftUI

struct BatteryView: View {
    @State private var battery: BatteryInfo?
    @State private var noBattery = false

    var body: some View {
        Form {
            if let battery {
                Section {
                    LabeledContent {
                        BilingualLabel(battery.condition, alignment: .trailing)
                    } label: {
                        BilingualLabel(en: "Condition", ru: "Состояние")
                    }
                    LabeledContent {
                        Text(String(format: "%.1f%%", battery.healthPercent))
                    } label: {
                        BilingualLabel(en: "Health", ru: "Износ")
                    }
                    LabeledContent {
                        Text("\(battery.cycleCount)")
                    } label: {
                        BilingualLabel(en: "Cycle Count", ru: "Циклы заряда")
                    }
                    LabeledContent {
                        Text("\(battery.designCapacity) mAh")
                    } label: {
                        BilingualLabel(en: "Design Capacity", ru: "Проектная ёмкость")
                    }
                    LabeledContent {
                        Text("\(battery.maxCapacity) mAh")
                    } label: {
                        BilingualLabel(en: "Current Max Capacity", ru: "Текущая максимальная ёмкость")
                    }
                } header: {
                    BilingualLabel(en: "Health", ru: "Здоровье")
                }

                Section {
                    LabeledContent {
                        Text(String(format: "%.0f%%", battery.chargePercent))
                    } label: {
                        BilingualLabel(en: "Charge", ru: "Заряд")
                    }
                    LabeledContent {
                        BilingualLabel(en: battery.isCharging ? "Yes" : "No", ru: battery.isCharging ? "Да" : "Нет", alignment: .trailing)
                    } label: {
                        BilingualLabel(en: "Charging", ru: "Заряжается")
                    }
                    if let temp = battery.temperatureCelsius {
                        LabeledContent {
                            Text(String(format: "%.1f°C", temp))
                        } label: {
                            BilingualLabel(en: "Temperature", ru: "Температура")
                        }
                    }
                } header: {
                    BilingualLabel(en: "Live Status", ru: "Текущее состояние")
                }

                if let hint = recommendation(for: battery) {
                    Section {
                        BilingualLabel(hint)
                            .font(.callout)
                            .foregroundStyle(.orange)
                    } header: {
                        BilingualLabel(en: "Recommendation", ru: "Рекомендация")
                    }
                }
            } else if noBattery {
                BilingualLabel(en: "No battery detected (desktop Mac)", ru: "Батарея не обнаружена (настольный Mac)")
            } else {
                ProgressView()
            }

            Button {
                load()
            } label: {
                BilingualLabel(en: "Refresh", ru: "Обновить")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { load() }
    }

    private func load() {
        battery = BatteryInfo.read()
        noBattery = (battery == nil)
    }

    private func recommendation(for battery: BatteryInfo) -> BilingualText? {
        if battery.condition.en == "Service Recommended" {
            return BilingualText(
                en: "Apple reports a permanent fault — book a Genius Bar / authorized service appointment.",
                ru: "Apple сообщает о постоянной неисправности — обратитесь в авторизованный сервис."
            )
        }
        if battery.healthPercent < 80 {
            return BilingualText(
                en: "Battery health is below 80% — expect reduced runtime; consider a battery replacement.",
                ru: "Износ батареи выше 20% — время работы заметно снижено, стоит задуматься о замене."
            )
        }
        if let temp = battery.temperatureCelsius, temp > 40 {
            return BilingualText(
                en: "Battery temperature is high (\(String(format: "%.0f", temp))°C) — ensure vents aren't blocked and avoid charging in direct sun/heat.",
                ru: "Высокая температура батареи (\(String(format: "%.0f", temp))°C) — проверьте вентиляцию и не заряжайте на солнце/в тепле."
            )
        }
        return nil
    }
}

#Preview {
    BatteryView()
}
